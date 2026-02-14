module turnt.queue;

import std.format : format;
import std.stdio : writeln;
import std.array : empty;
import std.random : randomShuffle, Random, unpredictableSeed;

import gst.bus;
import gst.element;
import gst.global : init_, parseLaunch;
import gst.message;
import gst.types : State, MessageType;
import glib.source : Source;

import mutagen.parser.scanner : musicDir;

private string encodeUri(string path)
{
    string result;
    foreach (char c; path)
    {
        if ((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') ||
            (c >= '0' && c <= '9') || c == '-' || c == '_' ||
            c == '.' || c == '~' || c == '/')
            result ~= c;
        else
            result ~= format("%%%02X", cast(ubyte)c);
    }
    return result;
}

class Queue
{
private:
    Element pipeline;
    Element pipelinePin;
    uint busWatchId;
    string[] tracks;
    int idx = -1;

    void onEos()
    {
        writeln("[queue] End of stream");
        if (idx >= 0 && idx + 1 < cast(int)tracks.length)
        {
            idx++;
            playRaw(tracks[idx]);
        }
        else if (loop && tracks.length > 0)
        {
            idx = 0;
            if (shuffle)
                reshuffle();
            playRaw(tracks[idx]);
        }
        else
            playing = false;
    }

    bool playRaw(string filePath)
    {
        stopPipeline();
        file = filePath;
        try
        {
            pipeline = cast(Element)parseLaunch("playbin uri=file://"~encodeUri(filePath));
            if (pipeline is null)
                return false;

            pipelinePin = pipeline;
            writeln("[queue] Playing: file://"~encodeUri(filePath));

            Bus bus = pipeline.getBus();
            if (bus !is null)
            {
                busWatchId = bus.addWatch(0, delegate bool(Bus, Message msg) {
                    MessageType t = msg.type;
                    if (t == MessageType.Eos)
                        onEos();
                    else if (t == MessageType.Error)
                    {
                        writeln("[queue] Pipeline error");
                        playing = false;
                    }
                    return true;
                });
            }

            pipeline.setState(State.Playing);
            playing = true;
            return true;
        }
        catch (Exception e)
            return false;
    }

    void stopPipeline()
    {
        if (busWatchId > 0)
        {
            Source.remove(busWatchId);
            busWatchId = 0;
        }
        if (pipeline !is null)
        {
            pipeline.setState(State.Null);
            pipeline = null;
            pipelinePin = null;
        }
        playing = false;
    }

    void reshuffle()
    {
        Random rng = Random(unpredictableSeed);
        randomShuffle(tracks, rng);
    }

public:
    bool shuffle;
    bool loop;
    bool playing;
    string file;
    string artist;
    string playlistName;

    this()
    {
        string[] empty;
        init_(empty);
    }

    void playQueue(string[] newTracks, string newArtist, int startIdx = 0)
    {
        if (newTracks.empty)
            return;
        tracks = newTracks.dup;
        artist = newArtist;
        playlistName = "";
        if (shuffle)
            reshuffle();
        idx = startIdx < cast(int)tracks.length ? startIdx : 0;
        playRaw(tracks[idx]);
    }

    void stop()
    {
        stopPipeline();
        tracks.length = 0;
        idx = -1;
        artist = "";
        file = "";
        playlistName = "";
    }

    void pause()
    {
        if (pipeline !is null && playing)
        {
            pipeline.setState(State.Paused);
            playing = false;
        }
    }

    void resume()
    {
        if (pipeline !is null && !playing)
        {
            pipeline.setState(State.Playing);
            playing = true;
        }
    }

    void togglePause()
    {
        if (playing)
            pause();
        else
            resume();
    }
}
