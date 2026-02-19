module mutagen.format.flac.block;

import std.stdio;
import std.string;
import std.variant;
import std.bitmanip;

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

struct Header
{
    uint length;
    Variant data;

    this(File file, out bool cont)
    {
        ubyte[4] bytes = file.rawRead(new ubyte[4]);
        cont = (bytes[0] & 0x80) == 0;
        HeaderType type = cast(HeaderType)(bytes[0] & 0x7F);
        length = (cast(uint)bytes[1] << 16)
            | (cast(uint)bytes[2] << 8)
            | (cast(uint)bytes[3]);

        if (type == HeaderType.VorbisComment)
            data = VorbisBlock(file);
        else if (type == HeaderType.Picture)
            data = PictureBlock(file);
    }
}

struct VorbisBlock
{
    string vendor;
    string[][string] tags;

    this(File file)
    {
        vendor = cast(string)file.rawRead(
            new char[](file.rawRead(new uint[1])[0])
        );

        foreach (i; 0..(file.rawRead(new uint[1])[0]))
        {
            uint len = file.rawRead(new uint[1])[0];
            string str = cast(string)file.rawRead(new char[](len));

            string[] parts = str.split('=');
            if (parts.length > 1)
                tags[parts[0].toUpper] ~= parts[1];
        }
    }
}

struct PictureBlock
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
        ubyte[4] bytes = file.rawRead(new ubyte[4]);
        pictureType = bigEndianToNative!uint(bytes);

        bytes = file.rawRead(new ubyte[4]);
        uint mimeLen = bigEndianToNative!uint(bytes);
        if (mimeLen > 0)
            mime = cast(string)file.rawRead(new char[](mimeLen));

        bytes = file.rawRead(new ubyte[4]);
        uint descLen = bigEndianToNative!uint(bytes);
        if (descLen > 0)
            description = cast(string)file.rawRead(new char[](descLen));

        bytes = file.rawRead(new ubyte[4]);
        width = bigEndianToNative!uint(bytes);

        bytes = file.rawRead(new ubyte[4]);
        height = bigEndianToNative!uint(bytes);

        bytes = file.rawRead(new ubyte[4]);
        depth = bigEndianToNative!uint(bytes);

        bytes = file.rawRead(new ubyte[4]);
        colors = bigEndianToNative!uint(bytes);

        bytes = file.rawRead(new ubyte[4]);
        uint imageLen = bigEndianToNative!uint(bytes);
        if (imageLen > 0)
            data = file.rawRead(new ubyte[](imageLen));
    }
}
