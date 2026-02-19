module mutagen.format.mp3;

import mutagen.format.mp3.frame;
import std.stdio;
import std.conv;
import std.string;

class MP3
{
    File file;
    Frame[] frames;
    ubyte[] imageData;

    this(File file)
    {
        this.file = file;

        if (file.size() < 10)
        {
            this.file.close();
            return;
        }

        ubyte[10] header = file.rawRead(new ubyte[10]);
        if (header[0..3] != cast(ubyte[])("ID3"))
        {
            this.file.close();
            return;
        }

        uint tagSize = (cast(uint)header[6] << 21)
            | (cast(uint)header[7] << 14)
            | (cast(uint)header[8] << 7)
            | cast(uint)header[9];
        ubyte ver = header[3];
        long end = 10 + cast(long)tagSize;

        while (file.tell() + 10 <= end && file.tell() + 10 <= file.size())
        {
            bool valid;
            Frame frame = Frame(file, ver, valid);
            if (!valid)
                break;
            frames ~= frame;

            if (imageData.length == 0)
            {
                if (frame.data.type == typeid(ApicFrame))
                {
                    ApicFrame apic = frame.data.get!ApicFrame;
                    imageData = apic.image;
                }
            }
        }

        this.file.close();
    }

    string[] opIndex(string str) const
    {
        str = str.toUpper();
        foreach (ref frame; frames)
        {
            if (frame.data.type == typeid(TxxxFrame))
            {
                const(TxxxFrame) txxx = frame.data.get!TxxxFrame;
                if (txxx.desc.toUpper() == str && txxx.value.length > 0)
                    return [txxx.value];
            }
            else if (frame.data.type == typeid(PcntFrame))
            {
                if (str == "PLAY_COUNT")
                {
                    const(PcntFrame) pcnt = frame.data.get!PcntFrame;
                    return [pcnt.count.to!string];
                }
            }
            else if (frame.data.type == typeid(TextFrame))
            {
                const(TextFrame) text = frame.data.get!TextFrame;
                if (text.id == "TIT2" && str == "TITLE")
                    return [text.text];
                else if (text.id == "TPE1" && str == "ARTIST")
                    return [text.text];
                else if (text.id == "TALB" && str == "ALBUM")
                    return [text.text];
                else if (text.id == "TRCK" && str == "TRACKNUMBER")
                    return [text.text];
                else if (text.id == str)
                    return [text.text];
            }
        }
        return null;
    }

    string opIndexAssign(string val, string tag)
    {
        tag = tag.toUpper();
        foreach (ref frame; frames)
        {
            if (frame.data.type == typeid(TxxxFrame))
            {
                TxxxFrame txxx = frame.data.get!TxxxFrame;
                if (txxx.desc.toUpper() == tag)
                {
                    txxx.value = val;
                    frame.data = txxx;
                    return val;
                }
            }
            else if (frame.data.type == typeid(PcntFrame))
            {
                if (tag == "PLAY_COUNT" || tag == "PCNT")
                {
                    PcntFrame pcnt = frame.data.get!PcntFrame;
                    pcnt.count = val.to!int;
                    frame.data = pcnt;
                    return val;
                }
            }
            else if (frame.data.type == typeid(TextFrame))
            {
                TextFrame text = frame.data.get!TextFrame;
                if ((text.id == "TIT2" && tag == "TITLE") ||
                    (text.id == "TPE1" && tag == "ARTIST") ||
                    (text.id == "TALB" && tag == "ALBUM") ||
                    (text.id == "TRCK" && tag == "TRACKNUMBER") ||
                    (text.id == tag))
                {
                    text.text = val;
                    frame.data = text;
                    return val;
                }
            }
        }

        if (tag == "PLAY_COUNT" || tag == "PCNT")
        {
            Frame f;
            PcntFrame p;
            p.count = val.to!int;
            f.data = p;
            frames ~= f;
            return val;
        }
        return val;
    }

    ubyte[] image() const
    {
        return imageData.dup;
    }
}
