module mutagen.format.mp4;

public import mutagen.format.mp4.atom;

import std.stdio : File, SEEK_SET;
import std.string : toUpper;
import std.bitmanip : bigEndianToNative;

class MP4
{
    File file;
    Atom[] atoms;
    ubyte[] image;

    this(File file)
    {
        this.file = file;

        while (file.tell() + 8 <= file.size())
        {
            long atomStart = file.tell();
            ubyte[8] header = file.rawRead(new ubyte[8]);
            
            ubyte[4] sizeBytes = header[0..4];
            uint atomSize = bigEndianToNative!uint(sizeBytes);
            string atomType = cast(string)header[4..8];

            if (atomSize < 8)
                break;

            long atomEnd = atomStart + atomSize;
            if (atomEnd > file.size())
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

            uint payloadSize = atomSize - 8;
            if (payloadSize > 0)
            {
                ubyte[] payload = file.rawRead(new ubyte[](payloadSize));
                Atom atom = Atom(header ~ payload, atomStart);
                atoms ~= atom;

                if (atomType == "covr" && image.length == 0)
                    image = parseCover(atom);
            }

            file.seek(atomEnd, SEEK_SET);
        }
        
        file.close();
    }

    string opIndex(string str)
    {
        str = str.toUpper();
        
        foreach (ref atom; atoms)
        {
            if (atom.id == "----")
            {
                string name;
                string value;
                parseFreeform(atom, name, value);
                if (name.toUpper() == str && value.length > 0)
                    return value;
            }
            else if (atom.id == "\xA9nam" && str == "TITLE")
                return cast(string)atom.data;
            else if (atom.id == "\xA9ART" && str == "ARTIST")
                return cast(string)atom.data;
            else if (atom.id == "\xA9alb" && str == "ALBUM")
                return cast(string)atom.data;
            else if (atom.id == "trkn" && str == "TRACKNUMBER")
                return cast(string)atom.data;
            else if (atom.id == str)
                return cast(string)atom.data;
        }
        return null;
    }

private:
    void parseRange(long start, long end)
    {
        file.seek(start, SEEK_SET);
        while (file.tell() + 8 <= end && file.tell() + 8 <= file.size())
        {
            long atomStart = file.tell();
            ubyte[8] header = file.rawRead(new ubyte[8]);
            
            ubyte[4] sizeBytes = header[0..4];
            uint atomSize = bigEndianToNative!uint(sizeBytes);
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

            uint payloadSize = atomSize - 8;
            if (payloadSize > 0)
            {
                ubyte[] payload = file.rawRead(new ubyte[](payloadSize));
                Atom atom = Atom(header ~ payload, atomStart);
                atoms ~= atom;

                if (atomType == "covr" && image.length == 0)
                    image = parseCover(atom);
            }

            file.seek(atomEnd, SEEK_SET);
        }
    }
}
