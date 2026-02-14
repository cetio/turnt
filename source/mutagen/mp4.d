module mutagen.mp4;

import std.conv : to;
import std.stdio : writeln, File, SEEK_CUR, SEEK_SET;
import std.string : toLower;

string readMp4Tag(string path, string tagName)
{
    try
    {
        File f = File(path, "rb");
        long fileSize = f.size();

        while (f.tell() + 8 <= fileSize)
        {
            ubyte[8] atomHeader;
            atomHeader = f.rawRead(new ubyte[8]);
            uint atomSize = (cast(uint)atomHeader[0] << 24)
                | (cast(uint)atomHeader[1] << 16)
                | (cast(uint)atomHeader[2] << 8)
                | cast(uint)atomHeader[3];
            string atomType = cast(string)atomHeader[4..8];

            if (atomSize < 8)
                break;

            if (atomType == "moov" || atomType == "udta" || atomType == "meta"
                || atomType == "ilst")
            {
                if (atomType == "meta")
                    f.seek(4, SEEK_CUR); // skip version/flags
                continue; // descend into container
            }

            if (atomType == "----")
            {
                string result = parseFreeformAtom(f, atomSize - 8, tagName);
                if (result.length > 0)
                {
                    f.close();
                    return result;
                }
            }
            else
            {
                long skip = atomSize - 8;
                if (skip > 0 && f.tell() + skip <= fileSize)
                    f.seek(skip, SEEK_CUR);
                else
                    break;
            }
        }
        f.close();
    }
    catch (Exception e)
        writeln("[mp4] Error reading tag: "~e.msg);
    return "";
}

void writeMp4Tag(string path, string tagName, string value)
{
    // Use subprocess for reliable MP4 tag writing
    import std.process : execute;
    // AtomicParsley or ffmpeg approach
    auto r = execute(["AtomicParsley", path, "--overWrite",
        "--freeform", "PLAY_COUNT", "--text", value]);
    if (r.status != 0)
    {
        // Fallback: try python3 mutagen
        auto r2 = execute(["python3", "-c",
            "import mutagen.mp4; f=mutagen.mp4.MP4('"~path~"');"
            ~"f['----:com.apple.iTunes:"~tagName~"']="
            ~"[mutagen.mp4.MP4FreeForm(b'"~value~"')]; f.save()"]);
        if (r2.status != 0)
            writeln("[playcount] MP4 write failed for "~path);
        else
            writeln("[playcount] Wrote MP4 play count via mutagen: "~value);
    }
    else
        writeln("[playcount] Wrote MP4 play count: "~value);
}

private string parseFreeformAtom(File f, long remaining, string tagName)
{
    long start = f.tell();
    string mean_, name_, data_;

    while (f.tell() - start < remaining)
    {
        if (f.tell() + 8 > f.size())
            break;

        ubyte[8] subHeader;
        subHeader = f.rawRead(new ubyte[8]);
        uint subSize = (cast(uint)subHeader[0] << 24)
            | (cast(uint)subHeader[1] << 16)
            | (cast(uint)subHeader[2] << 8)
            | cast(uint)subHeader[3];
        string subType = cast(string)subHeader[4..8];

        if (subSize < 8)
            break;

        uint payloadSize = subSize - 8;
        if (payloadSize == 0)
            continue;

        ubyte[] payload = f.rawRead(new ubyte[payloadSize]);

        if (subType == "mean" && payload.length > 4)
            mean_ = cast(string)payload[4..$];
        else if (subType == "name" && payload.length > 4)
            name_ = cast(string)payload[4..$];
        else if (subType == "data" && payload.length > 8)
            data_ = cast(string)payload[8..$];
    }

    // Seek to end of atom
    long endPos = start + remaining;
    if (endPos <= f.size())
        f.seek(endPos, SEEK_SET);

    if (name_.toLower() == tagName.toLower())
        return data_;
    return "";
}
