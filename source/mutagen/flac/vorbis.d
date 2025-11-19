module mutagen.flac.vorbis;

import std.conv;
import std.stdio;
import std.string;
import core.exception;

struct Vorbis
{
    string vendor;
    string[string] tags;

    this(File file)
    {
        vendor = cast(string)file.rawRead(
            new char[](file.rawRead(new uint[1])[0])
        );

        foreach (i; 0..(file.rawRead(new uint[1])[0]))
        {
            uint len = file.rawRead(new uint[1])[0];
            string str = cast(string)file.rawRead(new char[](len));

            // TODO: Multiple tags for the same field.
            string[] parts = str.split('=');
            if (parts.length > 1)
                tags[parts[0]] = parts[1];
        }
    }
}
