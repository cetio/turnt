module mutagen.flac;

public import mutagen.flac.vorbis;

import std.stdio : File, SEEK_CUR;
import std.variant : Variant;

enum HeaderType : ubyte
{
    StreamInfo,
    Padding,
    Application,
    SeekTable,
    VorbisComment,
    CueSheet,
    Picture
}

private uint readBe32(File file)
{
    ubyte[4] bytes = file.rawRead(new ubyte[4]);
    return (cast(uint)bytes[0] << 24)
        | (cast(uint)bytes[1] << 16)
        | (cast(uint)bytes[2] << 8)
        | cast(uint)bytes[3];
}

struct Picture
{
    uint pictureType;
    string mime;
    string description;
    uint width;
    uint height;
    uint depth;
    uint colors;
    ubyte[] data;

    this(File file)
    {
        pictureType = readBe32(file);

        uint mimeLen = readBe32(file);
        if (mimeLen > 0)
            mime = cast(string)file.rawRead(new char[](mimeLen));

        uint descLen = readBe32(file);
        if (descLen > 0)
            description = cast(string)file.rawRead(new char[](descLen));

        width = readBe32(file);
        height = readBe32(file);
        depth = readBe32(file);
        colors = readBe32(file);

        uint imageLen = readBe32(file);
        if (imageLen > 0)
            data = file.rawRead(new ubyte[](imageLen));
    }
}

struct Header
{
    HeaderType type;
    uint length;
    Variant data;

    this(File file, out bool cont)
    {
        ubyte[4] bytes = file.rawRead(new ubyte[4]);
        cont = (bytes[0] & 0x80) == 0;
        type = cast(HeaderType)(bytes[0] & 0x7F);
        length = (cast(uint)bytes[1] << 16)
            | (cast(uint)bytes[2] << 8)
            | (cast(uint)bytes[3]);

        if (type == HeaderType.VorbisComment)
            data = Vorbis(file);
        else if (type == HeaderType.Picture)
            data = Picture(file);
    }
}

class FLAC
{
    File file;
    Header[] headers;

    this(File file)
    {
        this.file = file;
        if (file.rawRead(new char[4]) != "fLaC")
            throw new Exception("File does not have valid 'fLaC' magic!");

        while (!file.eof)
        {
            bool cont;
            Header header = Header(file, cont);

            headers ~= header;
            if (!cont)
                break;

            if (header.type != HeaderType.VorbisComment
                && header.type != HeaderType.Picture)
            {
                if (header.length > file.size() - file.tell())
                    break;

                file.seek(header.length, SEEK_CUR);
            }
        }
        file.close();
    }
}
