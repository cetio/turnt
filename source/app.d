import std.stdio;
import mutagen.flac;
import std.algorithm;
import std.file;
import std.array : array, empty;
import std.string;
import std.uni;

class Track
{
    File file;
    Vorbis vorbis;

    string name;
    string[] artists;
    ushort year;

    this(File file, Vorbis vorbis)
    {
        this.file = file;
        this.vorbis = vorbis;
    }
}

enum AlbumType
{
    Single,
    EP,
    LP
}

struct Album
{
    AlbumType type;
    Track[] tracks;
}

struct Node
{
    Track track;
    string name;
    string[] parts;
}

string[2] match(
    string[][string] names,
    ref Node node, 
    ptrdiff_t limit, 
    ptrdiff_t tolerance,
    size_t offset
)
{
    writeln(node);
    size_t maxLength = offset + limit < node.parts.length 
        ? offset + limit
        : node.parts.length;

    string str;
    foreach (i; offset..maxLength)
    {
        string part = node.parts[i];
        if (i > offset)
            str ~= ' '~part;
        else
            str = part;

        if (str in names)
        {
            if (tolerance > 0)
                node.parts = node.parts[++i..$];
            return [str, null];
        }
    }

    if (tolerance > 0)
    {
        if (offset + tolerance >= node.parts.length)
        {
            node.parts = null;
            return [str, null];
        }
        else if (match(names, node, tolerance, 0, offset + tolerance)[0] != null)
        {
            str = node.parts[offset..(offset + tolerance)].join(' ');
            node.parts = node.parts[(offset + tolerance)..$];
            return [str, null];
        }
    }

    return [null, null];
}

void parseArtists(ref Track[] tracks)
{
    Node[][size_t] nodes;
    string[][string] names;
    foreach (ref track; tracks)
    {
        Node node = Node(
            track,
            track.vorbis.tags["ARTIST"],
            track.vorbis.tags["ARTIST"].split!(x => x == ',' || x == ';').map!(x => x.toLower().strip()).array
        );

        if (node.parts.length == 1)
        {
            if (node.parts[0] !in names)
                names[node.parts[0]] = [node.name];
            else
                names[node.parts[0]] ~= node.name;
            continue;
        }

        if (node.parts.length !in nodes)
            nodes[node.parts.length] = [node];
        else
            nodes[node.parts.length] ~= node;
    }

    size_t[] ordinals = nodes.keys.sort().array;
    foreach (i, ordinal; ordinals[0..2])
    {
        ptrdiff_t tolerance = 1;
        ptrdiff_t limit = 1;
        if (i > 0)
            limit = ordinals[i - 1];
            
        foreach (node; nodes[ordinal])
        {
            while (node.parts.length > 0)
            {
                string[2] match = match(names, node, limit, tolerance, 0);
                if (match[0] == null)
                    break;

                writeln(match);
            }
        }
    }
}

void main()
{
    Track[] tracks;
    foreach (ent; dirEntries("/home/cet/Music", SpanMode.depth))
    {
        if (ent.name.length < 5 || ent.name[$-5..$] != ".flac")
            continue;

        File file = File(ent.name);
        Track track = new Track(
            file,
            new FLAC(file).headers.filter!(x => x.type == HeaderType.VorbisComment).array[0].data.get!Vorbis()
        );
        tracks ~= track;
    }

    parseArtists(tracks);
    // foreach (track; tracks)
    //     writeln(track.artists);
}
