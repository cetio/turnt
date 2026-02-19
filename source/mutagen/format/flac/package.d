module mutagen.format.flac;

import mutagen.format.flac.block;
import std.stdio;
import std.string;
import std.variant;

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

            if (header.data.type != typeid(VorbisBlock)
                && header.data.type != typeid(PictureBlock))
            {
                if (header.length > file.size() - file.tell())
                    break;

                file.seek(header.length, SEEK_CUR);
            }
        }
        file.close();
    }

    string[] opIndex(string str) const
    {
        str = str.toUpper();
        
        foreach (ref header; headers)
        {
            if (header.data.type == typeid(VorbisBlock))
            {
                const(VorbisBlock) v = header.data.get!VorbisBlock;
                if (str in v.tags)
                    return v.tags[str].dup;
            }
        }
        return null;
    }

    string opIndexAssign(string val, string tag)
    {
        tag = tag.toUpper();

        foreach (ref header; headers)
        {
            if (header.data.type == typeid(VorbisBlock))
            {
                VorbisBlock v = header.data.get!VorbisBlock;
                v.tags[tag] = [val];
                header.data = v;
                return val;
            }
        }
        
        Header h;
        VorbisBlock v;
        v.tags[tag] = [val];
        h.data = v;
        headers ~= h;
        return val;
    }

    ubyte[] image() const
    {
        foreach (ref header; headers)
        {
            if (header.data.type == typeid(PictureBlock))
            {
                const(PictureBlock) p = header.data.get!PictureBlock;
                return p.data.dup;
            }
        }
        return [];
    }
}
