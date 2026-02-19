module mutagen.format.mp4;

import mutagen.format.mp4.atom;
import std.stdio;
import std.string;
import std.bitmanip;

class MP4
{
    File file;
    Atom[] atoms;
    ubyte[] imageData;

    this(File file)
    {
        this.file = file;
        parseRange(file.tell(), file.size());
        this.file.close();
    }

    private void parseRange(long start, long end)
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
                Atom atom = Atom(header ~ payload);
                atoms ~= atom;

                if (atomType == "covr" && imageData.length == 0)
                {
                    if (atom.data.type == typeid(CoverAtom))
                    {
                        CoverAtom covr = atom.data.get!CoverAtom;
                        imageData = covr.image;
                    }
                }
            }

            file.seek(atomEnd, SEEK_SET);
        }
    }

    string[] opIndex(string str) const
    {
        str = str.toUpper();
        
        foreach (ref atom; atoms)
        {
            if (atom.data.type == typeid(FreeformAtom))
            {
                const(FreeformAtom) f = atom.data.get!FreeformAtom;
                if (f.name.toUpper() == str && f.value.length > 0)
                    return [f.value];
            }
            else if (atom.data.type == typeid(TextAtom))
            {
                const(TextAtom) t = atom.data.get!TextAtom;
                if (t.id == "\xA9nam" && str == "TITLE")
                    return [t.text];
                else if (t.id == "\xA9ART" && str == "ARTIST")
                    return [t.text];
                else if (t.id == "\xA9alb" && str == "ALBUM")
                    return [t.text];
                else if (t.id == "trkn" && str == "TRACKNUMBER")
                    return [t.text];
                else if (t.id.toUpper() == str)
                    return [t.text];
            }
        }
        return null;
    }

    string opIndexAssign(string val, string tag)
    {
        tag = tag.toUpper();
        
        foreach (ref atom; atoms)
        {
            if (atom.data.type == typeid(FreeformAtom))
            {
                FreeformAtom f = atom.data.get!FreeformAtom;
                if (f.name.toUpper() == tag)
                {
                    f.value = val;
                    atom.data = f;
                    return val;
                }
            }
            else if (atom.data.type == typeid(TextAtom))
            {
                TextAtom t = atom.data.get!TextAtom;
                if ((t.id == "\xA9nam" && tag == "TITLE") ||
                    (t.id == "\xA9ART" && tag == "ARTIST") ||
                    (t.id == "\xA9alb" && tag == "ALBUM") ||
                    (t.id == "trkn" && tag == "TRACKNUMBER") ||
                    (t.id.toUpper() == tag))
                {
                    t.text = val;
                    atom.data = t;
                    return val;
                }
            }
        }

        if (tag == "PLAY_COUNT" || tag == "PCNT")
        {
            Atom a;
            FreeformAtom f;
            f.name = "PLAY_COUNT";
            f.value = val;
            a.data = f;
            atoms ~= a;
            return val;
        }
        return val;
    }

    ubyte[] image() const
    {
        return imageData.dup;
    }
}
