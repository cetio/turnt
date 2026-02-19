module mutagen.format.mp4.atom;

import std.bitmanip;
import std.string;
import std.variant;

struct Atom
{
    uint size;
    Variant data;

    this(ubyte[] headerData)
    {
        size = bigEndianToNative!uint(headerData[0..4]);
        string id = cast(string)headerData[4..8];
        
        ubyte[] payload;
        if (size > 8)
            payload = headerData[8..$];

        if (id == "----")
            data = FreeformAtom(payload);
        else if (id == "covr")
            data = CoverAtom(payload);
        else
            data = TextAtom(id, payload);
    }
}

struct FreeformAtom
{
    string name;
    string value;

    this(ubyte[] data)
    {
        size_t pos = 0;
        name = "";
        value = "";

        while (pos + 8 <= data.length)
        {
            ubyte[4] sizeBytes = data[pos..pos + 4];
            uint subSize = bigEndianToNative!uint(sizeBytes);
            if (subSize < 8 || pos + subSize > data.length)
                break;

            string subType = cast(string)data[pos + 4..pos + 8];
            ubyte[] payload = data[pos + 8..pos + subSize];

            if (subType == "name" && payload.length > 4)
                name = cast(string)payload[4..$];
            else if (subType == "data" && payload.length > 8)
                value = cast(string)payload[8..$];

            pos += subSize;
        }
    }
}

struct CoverAtom
{
    ubyte[] image;

    this(ubyte[] data)
    {
        size_t pos = 0;
        while (pos + 8 <= data.length)
        {
            ubyte[4] sizeBytes = data[pos..pos + 4];
            uint subSize = bigEndianToNative!uint(sizeBytes);
            if (subSize < 8 || pos + subSize > data.length)
                break;

            string subType = cast(string)data[pos + 4..pos + 8];
            if (subType == "data" && subSize > 16)
            {
                image = data[pos + 16..pos + subSize].dup;
                break;
            }
            pos += subSize;
        }
    }
}

struct TextAtom
{
    string id;
    string text;

    this(string id, ubyte[] data)
    {
        this.id = id;
        this.text = cast(string)data;
    }
}
