// sporking + rendering test

chugl gfx;
gfx.gl @=> OpenGL @ gl;

//gfx.openWindow(512, 512);
gfx.fullscreen();

gfx.width() => float WIDTH;
gfx.height() => float HEIGHT;

100 => float r;
[-r, -r,
  r, -r,
 -r,  r,
  r,  r ]
@=> float geo[];

[0.0, 0.0, 
 1.0, 0.0, 
 0.0, 1.0,
 1.0, 1.0]
@=> float texcoord[];

chuglImage img;
img.load(me.dir()+"flare.png");

Image img2;
img2.load(me.dir()+"gypsy.jpg");

Video vid;
vid.open();

1::second => now;

<<< vid.width(), vid.height() >>>;

WIDTH/16 => float inc;
(WIDTH/inc) $int => int divwd;
(HEIGHT/inc) $int => int divht;

curveExp flicker[divwd][divht];
float phase[divwd][divht];
float freq[divwd][divht];
for(0 => int x; x < divwd; x++)
{
    for(0 => int y; y < divht; y++)
    {
        0 => flicker[x][y].val;
        1 => flicker[x][y].target;
        2 => flicker[x][y].t40;
        Std.rand2f(0, 180) => phase[x][y];
        50+Std.rand2f(-20, 20) => freq[x][y];
    }
}

while(true)
{
    gl.MatrixMode(gl.PROJECTION);
    gl.LoadIdentity();
    gl.Ortho(0, WIDTH, 0, HEIGHT, -100, 100);
    
    gl.MatrixMode(gl.MODELVIEW);
    
    for(0 => int x; x < divwd; x++)
    {
        for(0 => int y; y < divht; y++)
        {
            if(flicker[x][y].target() == 1)
            {
                if(Std.rand2f(0,1) < 0.0001)
                    0 => flicker[x][y].target;
            }
            else if(flicker[x][y].target() == 0)
            {
                if(Std.rand2f(0,1) < 0.005)
                    1 => flicker[x][y].target;
            }
            
            ((x$float)/divwd*vid.width()) $int => int imgx;
            ((y$float)/divht*vid.height()) $int => int imgy;
            vid.height()-imgy => imgy;
            
            vid.pixel(imgx, imgy) => int pix;
            //((pix>>24)&0xFF)/255.0 => float a; ((pix>>16)&0xFF)/255.0 => float b; 
            //((pix>>8)&0xFF)/255.0 => float g;  ((pix>>0)&0xFF)/255.0 => float r;
            ((pix>>0)&0xFF)/255.0 => float b; ((pix>>8)&0xFF)/255.0 => float g; 
            ((pix>>16)&0xFF)/255.0 => float r;  ((pix>24)&0xFF)/255.0 => float a;
            
            //(r+g+b)/3 => r;
            //Math.pow(r,0.25) => r;
            //Math.pow(g,10) => g;
            //Math.pow(b,10) => b;
            
            gl.PushMatrix();
            
            gl.Enable(gl.BLEND);
            gl.BlendFunc(gl.SRC_ALPHA, gl.ONE);
            
            //gfx.hsv(h, s, 1.0, c.val()*0.83);
            flicker[x][y].val() => float val;
            gl.Color4f(r*val, g*val, b*val, 0.83*val);
            gl.DisableClientState(gl.COLOR_ARRAY);
            
            gl.Translatef(x*inc, y*inc, 0.0);
            gl.Rotatef(phase[x][y]+now/second*freq[x][y], 0.01, 0.01, 1);
            //gl.Rotatef(phase[x][y]+now/second*freq[x][y]*0.01, 0, 1, 0);
            //gl.Rotatef(phase[x][y]+now/second*freq[x][y]*0.01, 1, 0, 0);
            gl.Scalef(flicker[x][y].val(), flicker[x][y].val(), 1);
            
            gl.VertexPointer(2, gl.DOUBLE, 0, geo);
            gl.EnableClientState(gl.VERTEX_ARRAY);
            
            gl.Enable(gl.TEXTURE_2D);
            gl.BindTexture(gl.TEXTURE_2D, img.tex());
            gl.TexCoordPointer(2, gl.DOUBLE, 0, texcoord);
            gl.EnableClientState(gl.TEXTURE_COORD_ARRAY);
            
            gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4);
            gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4);
            
            gl.PopMatrix();            
        }
    }
    
    (1.0/30.0)::second => now;
}
