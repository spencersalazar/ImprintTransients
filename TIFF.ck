
class TIFF
{
    float pixels[][];
    
    fun int open(string path)
    {
        FileIO f;
        f.open(path, FileIO.READ | FileIO.BINARY);
        
        f.readInt(IO.READ_INT8) => int bom1;
        f.readInt(IO.READ_INT8) => int bom2;
        
        readBE16(f) => int magic;
        
        <<< "header:", bom1, bom2, magic >>>;
        
        readBE32(f) => int ifd;
        
        f.seek(ifd);
        
        readBE16(f) => int nfields;
        
        <<< "nfields:", nfields >>>;
        
        for(0 => int i; i < nfields; i++)
        {
            readBE16(f) => int tag;
            readBE16(f) => int fieldtype;
            readBE32(f) => int nvalues;
            int valueoffset;
            if(fieldtype == 1 || fieldtype == 2) // byte || ascii
            {
                f.readInt(IO.READ_INT8) => valueoffset;
                f.readInt(IO.READ_INT8);
                f.readInt(IO.READ_INT8);
                f.readInt(IO.READ_INT8);
            }
            else if(fieldtype == 3) // short
            {
                readBE16(f) => valueoffset;
                f.readInt(IO.READ_INT16);
            }
            else
            {
                readBE32(f) => valueoffset;
            }
            
            <<< "field: ", tag, fieldtype, nvalues, valueoffset >>>;
        }
    }
    
    fun int readBE16(FileIO f)
    {
        f.readInt(IO.READ_INT8) => int msB;
        f.readInt(IO.READ_INT8) => int lsB;
        <<< msB, lsB >>>;
        return (msB << 8) | lsB;
    }
    
    fun int readBE32(FileIO f)
    {
        f.readInt(IO.READ_INT8) => int msB;
        f.readInt(IO.READ_INT8) => int smsB;
        f.readInt(IO.READ_INT8) => int tmsB;
        f.readInt(IO.READ_INT8) => int lsB;
        
        return (msB << 24) | (smsB << 16) | (tmsB << 8) | lsB;
    }
}


TIFF img;
img.open(me.dir()+"/gypsy.tiff");
