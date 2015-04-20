adc => FFT fft =^ Flux flux => blackhole;

4096 => fft.size;
Windowing.hann(fft.size()) => fft.window;
fft.size()/4 => int HOP_SIZE;

while(true)
{
    flux.upchuck();
    <<< flux.fval(0) >>>;
    
    HOP_SIZE::samp => now;
}