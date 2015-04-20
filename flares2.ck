// sporking + rendering test

curveExp ping;
1 => ping.target;

fun void computeFlux()
{
    adc => FFT fft =^ Flux flux => blackhole;
    
    1024 => fft.size;
    Windowing.hann(fft.size()) => fft.window;
    fft.size()/4 => int HOP_SIZE;

    while(true)
    {
        flux.upchuck();
        if(flux.fval(0) > 0.75)
            1+8*flux.fval(0) => ping.target;
        
        HOP_SIZE::samp => now;
    }
}

spork ~ computeFlux();

chugl gfx;
gfx.gl @=> OpenGL @ gl;

//gfx.openWindow(512, 512);
gfx.fullscreen();

gfx.width() => float WIDTH;
gfx.height() => float HEIGHT;

WIDTH/30 => float inc;
75 => float r;

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

//Image img2;
//img2.load(me.dir()+"gypsy.jpg");

Video vid;
vid.open();

//1::second => now;

<<< vid.width(), vid.height() >>>;

(WIDTH/inc) $int => int divwd;
(HEIGHT/inc) $int => int divht;

curveExp flicker[divwd][divht];
float phase[divwd][divht];
float freq[divwd][divht];
float scale[divwd][divht];
for(0 => int x; x < divwd; x++)
{
    for(0 => int y; y < divht; y++)
    {
        0 => flicker[x][y].val;
        1 => flicker[x][y].target;
        2 => flicker[x][y].t40;
        Std.rand2f(0, 180) => phase[x][y];
        50+Std.rand2f(-20, 20) => freq[x][y];
        Math.pow(2,Std.rand2f(-0.01,0.01)) => scale[x][y];
    }
}

while(true)
{
    gl.MatrixMode(gl.PROJECTION);
    gl.LoadIdentity();
    gl.Ortho(0, WIDTH, 0, HEIGHT, -10, 100);
    
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
            // flip y axis (because +y in opengl is bottom->top)
            vid.height()-imgy => imgy;
            // flip x axis (for mirroring effect)
            vid.width()-imgx => imgx;
            
            vid.pixel(imgx, imgy, (inc*2)$int) => int pix;
            //((pix>>24)&0xFF)/255.0 => float a; ((pix>>16)&0xFF)/255.0 => float b; 
            //((pix>>8)&0xFF)/255.0 => float g;  ((pix>>0)&0xFF)/255.0 => float r;
            ((pix>>0)&0xFF)/255.0 => float b; ((pix>>8)&0xFF)/255.0 => float g; 
            ((pix>>16)&0xFF)/255.0 => float r;  ((pix>24)&0xFF)/255.0 => float a;
            
            //(r+g+b)/3 => r;
            //Math.pow(r,0.25) => r;
            //Math.pow(g,10) => g;
            //Math.pow(b,10) => b;
            
            // centralize color
            0.2126*r + 0.7152*g + 0.0722*b => float br;
            br => r;
            0 => g;
            0 => b;
            
            gl.PushMatrix();
            
            gl.Enable(gl.BLEND);
            gl.BlendFunc(gl.SRC_ALPHA, gl.ONE);
            
            //gfx.hsv(h, s, 1.0, c.val()*0.83);
            flicker[x][y].val() => float val;
            
            ping.val() => float pingVal;
            gl.Color4f(r*val*pingVal, g*val*pingVal, b*val*pingVal, 0.83*val);
            gl.DisableClientState(gl.COLOR_ARRAY);
            
            gl.Translatef(x*inc, y*inc, 0.0);
            gl.Rotatef(phase[x][y]+now/second*freq[x][y], 0.01, 0.01, 1);
            //gl.Rotatef(phase[x][y]+now/second*freq[x][y]*0.01, 0, 1, 0);
            //gl.Rotatef(phase[x][y]+now/second*freq[x][y]*0.01, 1, 0, 0);
            gl.Scalef(flicker[x][y].val()*scale[x][y], flicker[x][y].val()*scale[x][y], 1);
            
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
    
    1 => ping.target;
    
    (1.0/30.0)::second => now;
}
