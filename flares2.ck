// sporking + rendering test

class Flare
{
    float center_x, center_y;
    1 => float radius;
    float offset_x, offset_y;
    1 => float radiusScale;
    
    0 => int arrayIdx;
    2 => int vertDim;
    float vertArray[];
    float uvArray[];
    float colArray[];
    
    fun float setScale(float scale)
    {
        scale => radiusScale;
        //_updateGeo();
        return scale;
    }
    
    fun void setCenter(float _center_x, float _center_y)
    {
        _center_x => center_x;
        _center_y => center_y;
        //_updateGeo();
    }
    
    fun void setOffset(float _offset_x, float _offset_y)
    {
        _offset_x => offset_x;
        _offset_y => offset_y;
        //_updateGeo();
    }
    
    fun void setColor(float r, float g, float b, float a)
    {
        //chout <= r <= " " <= g <= " " <= b <= " " <= a <= "\n";
        r => colArray[arrayIdx*16+0*4+0] => colArray[arrayIdx*16+1*4+0] => colArray[arrayIdx*16+2*4+0] => colArray[arrayIdx*16+3*4+0];
        g => colArray[arrayIdx*16+0*4+1] => colArray[arrayIdx*16+1*4+1] => colArray[arrayIdx*16+2*4+1] => colArray[arrayIdx*16+3*4+1];
        b => colArray[arrayIdx*16+0*4+2] => colArray[arrayIdx*16+1*4+2] => colArray[arrayIdx*16+2*4+2] => colArray[arrayIdx*16+3*4+2];
        a => colArray[arrayIdx*16+0*4+3] => colArray[arrayIdx*16+1*4+3] => colArray[arrayIdx*16+2*4+3] => colArray[arrayIdx*16+3*4+3];
    } 
    
    fun void updateGeo()
    {
        //<<< vertArray.size(), uvArray.size(), colArray.size() >>>;
        center_x + offset_x => float final_center_x;
        center_y + offset_y => float final_center_y;
        radius*radiusScale => float final_radius;
        
        final_center_x - final_radius => vertArray[arrayIdx*vertDim*4+0*vertDim+0];
        final_center_y - final_radius => vertArray[arrayIdx*vertDim*4+0*vertDim+1];
        
        final_center_x + final_radius => vertArray[arrayIdx*vertDim*4+1*vertDim+0];
        final_center_y - final_radius => vertArray[arrayIdx*vertDim*4+1*vertDim+1];
        
        final_center_x + final_radius => vertArray[arrayIdx*vertDim*4+2*vertDim+0];
        final_center_y + final_radius => vertArray[arrayIdx*vertDim*4+2*vertDim+1];

        final_center_x - final_radius => vertArray[arrayIdx*vertDim*4+3*vertDim+0];
        final_center_y + final_radius => vertArray[arrayIdx*vertDim*4+3*vertDim+1];
        
        0 => uvArray[arrayIdx*8+0*2+0]; 0 => uvArray[arrayIdx*8+0*2+1];
        1 => uvArray[arrayIdx*8+1*2+0]; 0 => uvArray[arrayIdx*8+1*2+1];
        1 => uvArray[arrayIdx*8+2*2+0]; 1 => uvArray[arrayIdx*8+2*2+1];
        0 => uvArray[arrayIdx*8+3*2+0]; 1 => uvArray[arrayIdx*8+3*2+1];
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

Video vid;
vid.open();
//3::second => now;
<<< vid.width(), vid.height() >>>;

chuglImage img;
img.load(me.dir()+"flare.png");

WIDTH/50 => float inc;
32*2 => float r;

1.5 => float MINI_JITTER;
27 => float JITTER_MAX_RADIUS;
4 => float SCALING_MAX;
2 => float br_reduction;
(1.0/30.0)::second => dur frame;


(WIDTH/inc) $int => int divwd;
(HEIGHT/inc) $int => int divht;

Flare flare[divwd][divht];
2 => int VERT_DIM;
float vertArray[VERT_DIM*4*divwd*divht];
float uvArray[2*4*divwd*divht];
float colArray[4*4*divwd*divht];

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
        VERT_DIM => flare[x][y].vertDim;
        vertArray @=> flare[x][y].vertArray;
        uvArray @=> flare[x][y].uvArray;
        colArray @=> flare[x][y].colArray;
        y*divwd+x => flare[x][y].arrayIdx;
        //<<< flare[x][y].arrayIdx >>>;
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

// cosine ramp from 0-1 with flattened midpoint
fun float xcurve(float x) { return 0.5*(1-Math.pow(Math.cos(x*0.5*2*pi), 3)); }

0 => float mono_r;
0 => float mono_g;
0 => float mono_b;
0 => float dr_smash;
0 => float jitter;
0 => float scaling;
1 => float reso;
1 => int RESO_MAX;

7 => int NMODES;
int modeActive[NMODES];

fun void update()
{
    while(true)
    {
        Math.random2(0, NMODES-1) => int mode;
        //6 => int mode;
        while(modeActive[mode] && mode != 0) (mode+1)%NMODES => mode;
        true => modeActive[mode];
        //Math.random2f(0.045, 0.055) => float freq;
        Math.random2f(0.055, 0.075) => float freq;
        
        0 => int up;
        
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
            // monochrome red
            mono_r < 0.5 => up;
            
            now => time start;
            0 => float phase;
            while(phase <= 1)
            {
                xcurve(phase) => float val;
                if(!up) 1-val => val;
                val => mono_r;
                (now-start)/second*freq => phase;
                
                frame => now;
            }            
        }
        else if(mode == 2)
        {
            // monochrome blue
            mono_b < 0.5 => up;
            
            now => time start;
            0 => float phase;
            while(phase <= 1)
            {
                xcurve(phase) => float val;
                if(!up) 1-val => val;
                val => mono_b;
                (now-start)/second*freq => phase;
                
                frame => now;
            }            
        }
        else if(mode == 3)
        {
            float sgn;
            if(dr_smash == 0)
                1-2*Math.random2(0,1) => sgn; // randomly -1 or 1
            else
                Math.sgn(dr_smash) => sgn;
            // dr_smash
            Math.fabs(dr_smash) < 0.5 => up;
            now => time start;
            0 => float phase;
            while(phase <= 1)
            {
                xcurve(phase) => float val;
                if(!up) 1-val => val;
                sgn*val => dr_smash;
                (now-start)/second*freq => phase;
                
                frame => now;
            }            
        }
        else if(mode == 4)
        {
            // jitter
            jitter < 0.5 => up;
            now => time start;
            0 => float phase;
            while(phase <= 1)
            {
                xcurve(phase) => float val;
                if(!up) 1-val => val;
                val => jitter;
                (now-start)/second*freq => phase;
                
                frame => now;
            }
        }
        else if(mode == 5)
        {
            // scaling
            scaling < 0.5 => up;
            now => time start;
            0 => float phase;
            while(phase <= 1)
            {
                xcurve(phase) => float val;
                if(!up) 1-val => val;
                val => scaling;
                (now-start)/second*freq => phase;
                
                frame => now;
            }
        }
        else if(mode == 6)
        {
            // reso up/down
            reso => float reso_start;
            float sgn;
            if(reso < 1) 1 => sgn;
            else if(reso > RESO_MAX-1) -1 => sgn;
            else (1-2*Math.random2(0,1)) => sgn; // randomly -1 or 1
            
            <<< "(mode 6) reso:", reso, "sgn:", sgn >>>;
            
            now => time start;
            0 => float phase;
            while(phase <= 1)
            {
                xcurve(phase) => float val;
                Std.clampf(reso_start+val*sgn, 0, RESO_MAX) => reso;
                (now-start)/second*freq => phase;
                
                frame => now;
            }
        }
        
        false => modeActive[mode];
    }    
}

spork ~ update();
spork ~ update();
spork ~ update();

0 => int frameCount;

while(true)
{    
    gl.MatrixMode(gl.PROJECTION);
    gl.LoadIdentity();
    gl.Ortho(0, WIDTH, 0, HEIGHT, -10, 100);
    
    gl.MatrixMode(gl.MODELVIEW);
    gl.LoadIdentity();
    
    Math.pow(2, RESO_MAX-Math.ceil(reso))$int => int reso_inc;
    if(reso_inc < 1) 1 => reso_inc;
    1.0/Math.pow(3, reso) => float reso_scale;
    (reso-Math.floor(reso)) => float reso_inc_scale;
    if(reso_inc_scale == 0) 1 => reso_inc_scale;
    Math.pow(reso_inc_scale, 2) => reso_inc_scale;
    
    if(frameCount%15 == 0)
        <<< "reso: ", reso, "reso_scale: ", reso_scale, "reso_inc_scale: ", reso_inc_scale >>>;
    //if(reso_inc == 0)
    //<<< "reso:", reso, "reso_inc:", reso_inc, "reso_scale:", reso_scale, "reso_inc_scale:", reso_inc_scale >>>;

    for(0 => int x; x < divwd; reso_inc +=> x)
    {
        for(0 => int y; y < divht; reso_inc +=> y)
        {
            ((x % (reso_inc*2))==reso_inc || (y % (reso_inc*2))==reso_inc) => int is_skip;
            
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
            
            //vid.pixel(imgx, imgy, (inc*2)$int) => int pix;
            vid.pixel(imgx, imgy) => int pix;
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
            // instead: contrast control
            //Math.pow(2, dr_smash*2) => float contrast_pow;
            //Std.scalef(Math.sgn(r)*Math.pow(Math.fabs(Std.scalef(r, 0, 1, -1, 1)), contrast_pow), -1, 1, 0, 1) => r;
            //Std.scalef(Math.sgn(g)*Math.pow(Math.fabs(Std.scalef(g, 0, 1, -1, 1)), contrast_pow), -1, 1, 0, 1) => g;
            //Std.scalef(Math.sgn(b)*Math.pow(Math.fabs(Std.scalef(b, 0, 1, -1, 1)), contrast_pow), -1, 1, 0, 1) => b;
            
            //gl.PushMatrix();
            
            flicker[x][y].val() => float val;
            0.83 => float alpha;
            if(is_skip) reso_inc_scale *=> alpha;
            
            ping.val() => float pingVal;
            flare[x][y].setColor(r*val*pingVal, g*val*pingVal, b*val*pingVal, alpha*val);
            
            //gl.Translatef(x*inc, y*inc, 0.0);
            //gl.Rotatef(phase[x][y]+now/second*freq[x][y], 0.01, 0.01, 1);
            //gl.Translatef(jitter*jitter_amt[x][y]*JITTER_MAX_RADIUS, jitter*jitter_amt[x][y]*JITTER_MAX_RADIUS, 0.0);
            flicker[x][y].val()*scale[x][y]*Math.pow(SCALING_MAX,scaling_amt[x][y]*scaling)*reso_scale => float scale;
            if(is_skip) reso_inc_scale *=> scale;
            MINI_JITTER + jitter*jitter_amt[x][y]*JITTER_MAX_RADIUS => float jitter_radius;
            phase[x][y]+now/second*freq[x][y] => float rotZ; // degrees
            //gl.Scalef(scale, scale, 1);
            flare[x][y].setCenter(x*inc, y*inc);
            flare[x][y].setOffset(jitter_radius*Math.cos(rotZ/180.0*pi), jitter_radius*Math.sin(rotZ/180.0*pi));
            flare[x][y].setScale(scale);
            flare[x][y].updateGeo();
            
            if(true)
            {
                gl.Enable(gl.BLEND);
                gl.BlendFunc(gl.SRC_ALPHA, gl.ONE);
                
                gl.ColorPointer(4, gl.DOUBLE, 0, colArray);
                gl.EnableClientState(gl.COLOR_ARRAY);
                
                gl.VertexPointer(2, gl.DOUBLE, 0, vertArray);
                gl.EnableClientState(gl.VERTEX_ARRAY);
                
                gl.Enable(gl.TEXTURE_2D);
                gl.BindTexture(gl.TEXTURE_2D, img.tex());
                
                gl.TexCoordPointer(2, gl.DOUBLE, 0, uvArray);
                gl.EnableClientState(gl.TEXTURE_COORD_ARRAY);
                
                gl.DrawArrays(gl.QUADS, flare[x][y].arrayIdx*4, 4);
                gl.DrawArrays(gl.QUADS, flare[x][y].arrayIdx*4, 4);
            }
        }
    }
        
    if(false)
    {
        gl.Enable(gl.BLEND);
        gl.BlendFunc(gl.SRC_ALPHA, gl.ONE);
        
        gl.ColorPointer(4, gl.DOUBLE, 0, colArray);
        gl.EnableClientState(gl.COLOR_ARRAY);
        
        gl.VertexPointer(2, gl.DOUBLE, 0, vertArray);
        gl.EnableClientState(gl.VERTEX_ARRAY);
        
        gl.Enable(gl.TEXTURE_2D);
        gl.BindTexture(gl.TEXTURE_2D, img.tex());
        
        gl.TexCoordPointer(2, gl.DOUBLE, 0, uvArray);
        gl.EnableClientState(gl.TEXTURE_COORD_ARRAY);
        
        gl.DrawArrays(gl.QUADS, 0, 4*divwd*divht);
        gl.DrawArrays(gl.QUADS, 0, 4*divwd*divht);
    }

    1 => ping.target;
    
    frame => now;
    
    frameCount++;
}

