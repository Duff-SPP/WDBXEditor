using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using WDBXEditor.Storage;

namespace WDBXEditor.Reader.FileTypes
{
    public class WDBC : DBHeader
    {
        // A raw layout is used only when the selected WotLK build has no definition.
        // On-disk values remain opaque: no string-offset or float interpretation is guessed.
        public bool IsRawLayout { get; set; }
        public byte[] OriginalStringBlock { get; set; } = new byte[0];
        public override void ReadHeader(ref BinaryReader dbReader, string signature)
        {
            base.ReadHeader(ref dbReader, signature);
        }
    }
}
