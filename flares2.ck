// sporking + rendering test

class Flare
{
    float center_x, center_y;
    1 => float radius;
    float offset_x, offset_y;
    1 => float radiusScale;
    
    0 => int arrayIdx;
    2 => int vertDim;
    float vertArray[vertDim*4];
    float uvArray[2*4];
    float colArray[4*4];
    
    fun float setScale(float scale)
    {
        scale => radiusScale;
        _updateGeo();
        return scale;
    }
    
    fun void setCenter(float _center_x, float _center_y)
    {
        _center_x => center_x;
        _center_y => center_y;
        _updateGeo();
    }
    
    fun void setOffset(float _offset_x, float _offset_y)
    {
        _offset_x => offset_x;
        _offset_y => offset_y;
        _updateGeo();
    }
    
    fun void setColor(float r, float g, float b, float a)
    {
        r => colArray[arrayIdx+0*4+0] => colArray[arrayIdx+1*4+0] => colArray[arrayIdx+2*4+0] => colArray[arrayIdx+3*4+0];
        g => colArray[arrayIdx+0*4+1] => colArray[arrayIdx+1*4+1] => colArray[arrayIdx+2*4+1] => colArray[arrayIdx+3*4+1];
        b => colArray[arrayIdx+0*4+2] => colArray[arrayIdx+1*4+2] => colArray[arrayIdx+2*4+2] => colArray[arrayIdx+3*4+2];
        a => colArray[arrayIdx+0*4+3] => colArray[arrayIdx+1*4+3] => colArray[arrayIdx+2*4+3] => colArray[arrayIdx+3*4+3];
    } 
    
    fun void _updateGeo()
    {
        //<<< vertArray.size(), uvArray.size(), colArray.size() >>>;
        center_x + offset_x => float _center_x;
        center_y + offset_y => float _center_y;
        radius*radiusScale => float _radius;
        
        center_x - radius => vertArray[arrayIdx+0*vertDim+0];
        center_y - radius => vertArray[arrayIdx+0*vertDim+1];
        
        center_x + radius => vertArray[arrayIdx+1*vertDim+0];
        center_y - radius => vertArray[arrayIdx+1*vertDim+1];
        
        center_x - radius => vertArray[arrayIdx+2*vertDim+0];
        center_y + radius => vertArray[arrayIdx+2*vertDim+1];

        center_x + radius => vertArray[arrayIdx+3*vertDim+0];
        center_y + radius => vertArray[arrayIdx+3*vertDim+1];
        
        0 => uvArray[arrayIdx+0*2+0]; 0 => uvArray[arrayIdx+0*2+1];
        1 => uvArray[arrayIdx+1*2+0]; 0 => uvArray[arrayIdx+1*2+1];
        0 => uvArray[arrayIdx+2*2+0]; 1 => uvArray[arrayIdx+2*2+1];
        1 => uvArray[arrayIdx+3*2+0]; 1 => uvArray[arrayIdx+3*2+1];
    }
}


curveExp ping;
1 => ping.target;

fun void computeFlux()
{
    adc => FFT fft =^ Flux flux => blackhole;
    fft =^ RMS rms => blackhole;
    
    1024 => fft.size;
    Windowing.hann(fft.size()) => fft.window;
    fft.size()/4 => int HOP_SIZE;

    while(true)
    {
        flux.upchuck();
        if(flux.fval(0) > 0.75)
            1+5*(rms.fval(0)+flux.fval(0)) => ping.target;
        
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

WIDTH/35 => float inc;
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


Flare flare[divwd][divht];
2 => int VERT_DIM;


curveExp flicker[divwd][divht];
float phase[divwd][divht];
float freq[divwd][divht];
float scale[divwd][divht];
float jitter_amt[divwd][divht];
float scaling_amt[divwd][divht];

for(0 => int x; x < divwd; x++)
{
    for(0 => int y; y < divht; y++)
    {
        //VERT_DIM => flare[x][y].vertDim;
        //float vertArray[VERT_DIM*4];
        //vertArray @=> flare[x][y].vertArray;
        //float uvArray[2*4];
        //uvArray @=> flare[x][y].uvArray;
        //float colArray[4*4];
        //colArray @=> flare[x][y].colArray;
        r => flare[x][y].radius;
        
        0 => flicker[x][y].val;
        1 => flicker[x][y].target;
        2 => flicker[x][y].t40;
        Math.random2f(0, 180) => phase[x][y];
        50+Math.random2f(-20, 20) => freq[x][y];
        Math.pow(2, Math.random2f(-0.01,0.01)) => scale[x][y];
        Math.random2f(0, 1) => jitter_amt[x][y];
        Math.random2f(-1, 1) => scaling_amt[x][y];
    }
}

(1.0/30.0)::second => dur frame;

// cosine ramp from 0-1 with flattened midpoint
fun float xcurve(float x) { return 0.5*(1-Math.pow(Math.cos(x*2*pi), 3)); }

0 => float mono_r;
0 => float mono_g;
0 => float mono_b;
0 => float dr_smash;
0 => float jitter;
0 => float scaling;

1 => float MINI_JITTER;
30 => float JITTER_MAX_RADIUS;
4 => float SCALING_MAX;
1.25 => float br_reduction;

fun void update()
{
    5 => int NMODES;
    while(true)
    {
        Math.random2(0, NMODES-1) => int mode;
        Math.random2f(0.045, 0.055) => float freq;
        
        if(mode == 0)
        {
            // do nothing
            now => time start;
            0 => float phase;
            while(phase <= 1)
            {
                xcurve(phase) => float val;
                (now-start)/second*freq => phase;
                
                frame => now;
            }
        }
        else if(mode == 1)
        {
            // monochromatic
            Math.random2(0, 2) => int mono_color;
            
            now => time start;
            0 => float phase;
            while(phase <= 1)
            {
                xcurve(phase) => float val;
                if(mono_color == 0) val => mono_r;
                else if(mono_color == 1) val => mono_g;
                else if(mono_color == 2) val => mono_b;
                (now-start)/second*freq => phase;
                
                frame => now;
            }            
        }
        else if(mode == 2)
        {
            1-Math.random2(0,2) => float sgn;
            // dr_smash
            now => time start;
            0 => float phase;
            while(phase <= 1)
            {
                xcurve(phase) => float val;
                sgn*val => dr_smash;
                (now-start)/second*freq => phase;
                
                frame => now;
            }            
        }
        else if(mode == 3)
        {
            // jitter
            now => time start;
            0 => float phase;
            while(phase <= 1)
            {
                xcurve(phase) => float val;
                val => jitter;
                (now-start)/second*freq => phase;
                
                frame => now;
            }
        }
        else if(mode == 4)
        {
            // scaling
            now => time start;
            0 => float phase;
            while(phase <= 1)
            {
                xcurve(phase) => float val;
                val => scaling;
                (now-start)/second*freq => phase;
                
                frame => now;
            }
        }
    }    
}

spork ~ update();
spork ~ update();
spork ~ update();

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
                if(Math.random2f(0,1) < 0.0001)
                    0 => flicker[x][y].target;
            }
            else if(flicker[x][y].target() == 0)
            {
                if(Math.random2f(0,1) < 0.005)
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
            
            // apply monochromaticism
            0.2126*r + 0.7152*g + 0.0722*b => float br;
            br*br_reduction + 1 => float br_reduce;
            br_reduce /=> r; br_reduce /=> g; br_reduce /=> b;
            br*(mono_r) + r*Std.clampf(1-(mono_r+mono_g+mono_b), 0, 1) => r;
            br*(mono_g) + g*Std.clampf(1-(mono_r+mono_g+mono_b), 0, 1) => g;
            br*(mono_b) + b*Std.clampf(1-(mono_r+mono_g+mono_b), 0, 1) => b;
            
            // apply dynamic range control
            Math.pow(r, Math.pow(2,dr_smash)) => r;
            Math.pow(g, Math.pow(2,dr_smash)) => g;
            Math.pow(b, Math.pow(2,dr_smash)) => b;
            
            gl.PushMatrix();
            
            gl.Enable(gl.BLEND);
            gl.BlendFunc(gl.SRC_ALPHA, gl.ONE);
            
            flicker[x][y].val() => float val;
            
            ping.val() => float pingVal;
            gl.Color4f(r*val*pingVal, g*val*pingVal, b*val*pingVal, 0.83*val);
            flare[x][y].setColor(r*val*pingVal, g*val*pingVal, b*val*pingVal, 0.83*val);
            gl.ColorPointer(4, gl.DOUBLE, 0, flare[x][y].colArray);
            gl.EnableClientState(gl.COLOR_ARRAY);
            //gl.DisableClientState(gl.COLOR_ARRAY);
            
            //gl.Translatef(x*inc, y*inc, 0.0);
            //gl.Rotatef(phase[x][y]+now/second*freq[x][y], 0.01, 0.01, 1);
            //gl.Translatef(jitter*jitter_amt[x][y]*JITTER_MAX_RADIUS, jitter*jitter_amt[x][y]*JITTER_MAX_RADIUS, 0.0);
            flicker[x][y].val()*scale[x][y]*Math.pow(SCALING_MAX,scaling_amt[x][y]*scaling) => float scale;
            MINI_JITTER + jitter*jitter_amt[x][y]*JITTER_MAX_RADIUS => float jitter_radius;
            phase[x][y]+now/second*freq[x][y] => float rotZ; // degrees
            //gl.Scalef(scale, scale, 1);
            flare[x][y].setCenter(x*inc, y*inc);
            flare[x][y].setOffset(jitter_radius*Math.cos(rotZ/180.0*pi), jitter_radius*Math.sin(rotZ/180.0*pi));
            flare[x][y].setScale(scale);
            
            gl.VertexPointer(2, gl.DOUBLE, 0, flare[x][y].vertArray);
            gl.EnableClientState(gl.VERTEX_ARRAY);
            
            gl.Enable(gl.TEXTURE_2D);
            gl.BindTexture(gl.TEXTURE_2D, img.tex());
            
            gl.TexCoordPointer(2, gl.DOUBLE, 0, flare[x][y].uvArray);
            gl.EnableClientState(gl.TEXTURE_COORD_ARRAY);
            
            gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4);
            gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4);
            
            gl.PopMatrix();
        }
    }
    
    1 => ping.target;
    
    frame => now;
}

