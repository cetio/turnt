module mutagen.mp4;

import std.conv : to;
import std.process : execute, ProcessResult;
import std.stdio : File, SEEK_SET;
import std.string : toUpper;

struct Atom
{
    string type;
    uint size;
    long dataStart;
    ubyte[] data;
}

final class MP4
{
public:
    string path;
    File file;
    Atom[] atoms;
    string[string] tags;
    ubyte[] image;

    this(string path)
    {
        this.path = path;
        parse();
    }

private:
    void parse()
    {
        try
        {
            file = File(path, "rb");
            parseRange(0, file.size());
            file.close();
        }
        catch (Exception)
        {
        }
    }

    void parseRange(long start, long end)
    {
        file.seek(start, SEEK_SET);
        while (file.tell() + 8 <= end && file.tell() + 8 <= file.size())
        {
            long atomStart = file.tell();
            ubyte[8] header = file.rawRead(new ubyte[8]);
            uint atomSize = (cast(uint)header[0] << 24)
                | (cast(uint)header[1] << 16)
                | (cast(uint)header[2] << 8)
                | cast(uint)header[3];
            string atomType = cast(string)header[4..8];

            if (atomSize < 8)
                break;

            long atomEnd = atomStart + atomSize;
            if (atomEnd > end || atomEnd > file.size())
                break;

            bool container = atomType == "moov" || atomType == "udta"
                || atomType == "meta" || atomType == "ilst"
                || atomType == "trak" || atomType == "mdia"
                || atomType == "minf" || atomType == "stbl";

            if (container)
            {
                long payloadStart = atomStart + 8;
                if (atomType == "meta")
                    payloadStart += 4;
                if (payloadStart < atomEnd)
                    parseRange(payloadStart, atomEnd);
                file.seek(atomEnd, SEEK_SET);
                continue;
            }

            Atom atom;
            atom.type = atomType;
            atom.size = atomSize;
            atom.dataStart = atomStart + 8;
            uint payloadSize = atomSize - 8;
            if (payloadSize > 0)
                atom.data = file.rawRead(new ubyte[](payloadSize));
            atoms ~= atom;

            if (atomType == "----")
                parseFreeform(atom);
            else if (atomType == "covr" && image.length == 0)
                image = parseCover(atom);

            file.seek(atomEnd, SEEK_SET);
        }
    }

    void parseFreeform(ref Atom atom)
    {
        size_t pos = 0;
        string name;
        string value;

        while (pos + 8 <= atom.data.length)
        {
            uint subSize = (cast(uint)atom.data[pos + 0] << 24)
                | (cast(uint)atom.data[pos + 1] << 16)
                | (cast(uint)atom.data[pos + 2] << 8)
                | cast(uint)atom.data[pos + 3];
            if (subSize < 8 || pos + subSize > atom.data.length)
                break;

            string subType = cast(string)atom.data[pos + 4..pos + 8];
            ubyte[] payload = atom.data[pos + 8..pos + subSize];

            if (subType == "name" && payload.length > 4)
                name = cast(string)payload[4..$];
            else if (subType == "data" && payload.length > 8)
                value = cast(string)payload[8..$];

            pos += subSize;
        }

        if (name.length > 0)
            tags[name.toUpper()] = value;
    }

    ubyte[] parseCover(ref Atom atom)
    {
        ubyte[] ret;
        size_t pos = 0;
        while (pos + 8 <= atom.data.length)
        {
            uint subSize = (cast(uint)atom.data[pos + 0] << 24)
                | (cast(uint)atom.data[pos + 1] << 16)
                | (cast(uint)atom.data[pos + 2] << 8)
                | cast(uint)atom.data[pos + 3];
            if (subSize < 8 || pos + subSize > atom.data.length)
                break;

            string subType = cast(string)atom.data[pos + 4..pos + 8];
            if (subType == "data" && subSize > 16)
            {
                ret = atom.data[pos + 16..pos + subSize].dup;
                break;
            }
            pos += subSize;
        }
        return ret;
    }
}

string readMp4Tag(string path, string tagName)
{
    MP4 mp4 = new MP4(path);
    string key = tagName.toUpper();
    if (string* value = key in mp4.tags)
        return *value;
    return "";
}

void writeMp4Tag(string path, string tagName, string value)
{
    ProcessResult result = execute(["AtomicParsley", path, "--overWrite",
        "--freeform", tagName, "--text", value]);
    if (result.status != 0)
    {
        ProcessResult fallback = execute([
            "python3", "-c",
            "import mutagen.mp4,sys;"
                ~"f=mutagen.mp4.MP4(sys.argv[1]);"
                ~"f['----:com.apple.iTunes:'+sys.argv[2]]="
                ~"[mutagen.mp4.MP4FreeForm(sys.argv[3].encode())];"
                ~"f.save()",
            path, tagName, value
        ]);
        if (fallback.status != 0)
        {
        }
    }
}
