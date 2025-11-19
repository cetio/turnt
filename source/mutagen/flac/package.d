module mutagen.flac;

public import mutagen.flac.vorbis;
import std.stdio;
import std.variant;

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
            if (cont && header.type != HeaderType.VorbisComment)
            {
                if (header.length > file.size() - file.tell())
                    break;

                file.seek(header.length, SEEK_CUR);
            }
            else
                break;
        }
        file.close();
    }
}
