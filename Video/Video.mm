
// this should align with the correct versions of these ChucK files
#include "chuck_dl.h"
#include "chuck_def.h"

#include <CoreFoundation/CoreFoundation.h>
#include <CoreGraphics/CoreGraphics.h>
#include <AVFoundation/AVFoundation.h>
#include <Accelerate/Accelerate.h>

#include <semaphore.h>

// general includes
#include <stdio.h>
#include <limits.h>


t_CKINT video_data_offset = 0;


/* Mac OS X video capture portions of this code were taken from the avvideowall
   example code 
 */

@interface AVCaptureInput (ConvenienceMethodsCategory)
- (AVCaptureInputPort *)portWithMediaType:(NSString *)mediaType;
@end

@implementation AVCaptureInput (ConvenienceMethodsCategory)


// Find the input port with the target media type
- (AVCaptureInputPort *)portWithMediaType:(NSString *)mediaType
{
    for (AVCaptureInputPort *p in [self ports]) {
        if ([[p mediaType] isEqualToString:mediaType])
            return p;
    }
    return nil;
}

@end


class Video;


@interface VideoBufferDelegate : NSObject<AVCaptureVideoDataOutputSampleBufferDelegate>
{
    Video *_video;
}

@property (nonatomic) Video *video;

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection;

@end


class Video
{
public:
    Video() : pixels(NULL), conv_pixels(NULL), width(0), height(0)
    {
        double_buffer_idx = 0;
        m_newData = NULL;
        m_filterReady = NULL;
        m_filterQueue = NULL;
        pixels_double_buffer[0] = NULL;
        pixels_double_buffer[1] = NULL;
    }
    
    ~Video()
    {
        m_doFilter = false;
        if(m_session)
        {
            [m_session stopRunning];
            [m_session release];
            m_session = nil;
        }
        
        if(conv_pixels) { free(conv_pixels); conv_pixels = NULL; }
        if(pixels_double_buffer[0]) { free(pixels_double_buffer[0]); pixels_double_buffer[0] = NULL; }
        if(pixels_double_buffer[1]) { free(pixels_double_buffer[1]); pixels_double_buffer[1] = NULL; }
        
        if(m_filterQueue) { dispatch_release(m_filterQueue); m_filterQueue = NULL; }
        if(m_newData) { sem_close(m_newData); m_newData = NULL; }
        if(m_filterReady) { sem_close(m_filterReady); m_filterReady = NULL; }
        
        sem_unlink("newData"); sem_unlink("filterReady");
    }
    
    t_CKBOOL open()
    {
        m_session = [AVCaptureSession new];
        // Set the session preset
        [m_session setSessionPreset:AVCaptureSessionPreset640x480];
        
        NSMutableArray *devices = [NSMutableArray array];
        for(AVCaptureDevice *device in [AVCaptureDevice devices])
        {
            if([device hasMediaType:AVMediaTypeVideo] || [device hasMediaType:AVMediaTypeMuxed])
            {
                NSLog(@"%@", [device localizedName]);
                [devices addObject:device];
            }
        }
        
        if([devices count] == 0)
        {
            NSLog(@"error: no video capture devices found");
            return FALSE;
        }
        
        AVCaptureDevice *device = [devices firstObject];
        
        NSError *error;
        AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
        if(error)
        {
            NSLog(@"deviceInputWithDevice: failed (%@)", error);
            return FALSE;
        }
        [m_session addInput:input];

        // Find the video input port
        //AVCaptureInputPort *videoPort = [input portWithMediaType:AVMediaTypeVideo];
        
        AVCaptureVideoDataOutput *output = [AVCaptureVideoDataOutput new];
        output.videoSettings = @{ (NSString *)kCVPixelBufferPixelFormatTypeKey: [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA] };
        m_delegate = [VideoBufferDelegate new];
        m_delegate.video = this;
        dispatch_queue_t queue = dispatch_queue_create("video_capture", DISPATCH_QUEUE_SERIAL);
        [output setSampleBufferDelegate:m_delegate queue:queue];
        dispatch_release(queue);
        
        NSLog(@"format types: %@", output.availableVideoCVPixelFormatTypes);
        
        [m_session addOutput:output];
        
        [m_session startRunning];
        //m_newData = false;
        
        sem_unlink("newData"); sem_unlink("filterReady");
        m_newData = sem_open("newData", O_CREAT|O_EXCL, S_IRUSR|S_IWUSR, 0);
        m_filterReady = sem_open("filterReady", O_CREAT|O_EXCL, S_IRUSR|S_IWUSR, 0);
        fprintf(stderr, "%0x %0x\n", m_newData, m_filterReady);
        m_filterQueue = dispatch_queue_create("edu.stanford.chuck.Video.filter", DISPATCH_QUEUE_SERIAL);
        dispatch_async(m_filterQueue, ^{
            m_doFilter = true;
            while(m_doFilter)
            {
                sem_post(m_filterReady);
                
                if(sem_wait(m_newData) == 0)
                {
                    fprintf(stderr, "filtering data\n");
                    //UInt32 *pixels = pixels_double_buffer[double_buffer_idx];
                    // filter
                    vImage_Buffer srcBuffer = {};
                    srcBuffer.data = pixels_double_buffer[double_buffer_idx];
                    srcBuffer.height = height; srcBuffer.width = width;
                    srcBuffer.rowBytes = bytesPerRow;
                    vImage_Buffer dstBuffer = {};
                    dstBuffer.data = conv_pixels;
                    dstBuffer.height = height; dstBuffer.width = width;
                    dstBuffer.rowBytes = bytesPerRow;
                    int filter_size = 17;
                    Pixel_8888 bgColor = {0, 0, 0, 0};
                    vImageTentConvolve_ARGB8888(&srcBuffer, &dstBuffer, NULL, 0, 0, 
                        filter_size, filter_size, bgColor, kvImageTruncateKernel);
                }
            }
        });
        
        return TRUE;
    }
    
    UInt32 *pixels;
    UInt32 *pixels_double_buffer[2];
    size_t double_buffer_idx;
    UInt32 *conv_pixels;
    UInt32 width, height, bytesPerRow;
    sem_t *m_newData;
    sem_t *m_filterReady;
    
protected:
    AVCaptureSession *m_session;
    VideoBufferDelegate *m_delegate;
    
    dispatch_queue_t m_filterQueue;
    bool m_doFilter;
    //bool m_newData;
};

@implementation VideoBufferDelegate

@synthesize video = _video;

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    CVImageBufferRef imgBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer); 
    /*Lock the image buffer*/
    CVPixelBufferLockBaseAddress(imageBuffer,0); 
    /*Get information about the image*/
    uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(imageBuffer); 
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer); 
    size_t width = CVPixelBufferGetWidth(imageBuffer); 
    size_t height = CVPixelBufferGetHeight(imageBuffer); 
    
    //NSLog(@"newFrame %lu %lu", width, height);
    
    if(sem_trywait(_video->m_filterReady) == 0)
    {
        fprintf(stderr, "loading new frame\n");
        UInt32 *pixels_double_buffer[2] = { NULL, NULL };
        pixels_double_buffer[0] = _video->pixels_double_buffer[0];
        pixels_double_buffer[1] = _video->pixels_double_buffer[1];
        // size_t double_buffer_idx = _video->double_buffer_idx;
        UInt32 *conv_pixels = _video->conv_pixels;
        bool doSet = false;
         
        if(pixels_double_buffer[0] == NULL)
        {
            doSet = true;
            NSLog(@"malloc %lu %lu", height*bytesPerRow, width*height*4);
            _video->double_buffer_idx = 0;
            pixels_double_buffer[0] = (UInt32 *) calloc(1, height*bytesPerRow);
            pixels_double_buffer[1] = (UInt32 *) calloc(1, height*bytesPerRow);
            conv_pixels = (UInt32 *) calloc(1, height*bytesPerRow);
        }
        
        size_t idx = (_video->double_buffer_idx+1)%2;
        memcpy(pixels_double_buffer[idx], baseAddress, height*bytesPerRow);
        _video->double_buffer_idx = idx;
        
        if(doSet)
        {
            _video->width = width;
            _video->height = height;
            _video->bytesPerRow = bytesPerRow;
            _video->pixels_double_buffer[0] = pixels_double_buffer[0];
            _video->pixels_double_buffer[1] = pixels_double_buffer[1];
            _video->conv_pixels = conv_pixels;
        }
        
        sem_post(_video->m_newData);
    }
    
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
}

@end


CK_DLL_CTOR(video_ctor)
{
    OBJ_MEMBER_INT(SELF, video_data_offset) = 0;
    
    Video * vid = new Video();
    
    OBJ_MEMBER_INT(SELF, video_data_offset) = (t_CKINT) vid;
}


CK_DLL_DTOR(video_dtor)
{
    Video * vid = (Video *) OBJ_MEMBER_INT(SELF, video_data_offset);
    if( vid )
    {
        delete vid;
        OBJ_MEMBER_INT(SELF, video_data_offset) = 0;
        vid = NULL;
    }
}

CK_DLL_MFUN(video_open)
{
    Video * vid = (Video *) OBJ_MEMBER_INT(SELF, video_data_offset);
    RETURN->v_int = vid->open();
}

CK_DLL_MFUN(video_openNamed)
{
    Video * vid = (Video *) OBJ_MEMBER_INT(SELF, video_data_offset);
    Chuck_String *str = GET_NEXT_STRING(ARGS);
    
    
    
    RETURN->v_int = 1;
}

CK_DLL_MFUN(video_width)
{
    Video * vid = (Video *) OBJ_MEMBER_INT(SELF, video_data_offset);
    RETURN->v_int = vid->width;
}

CK_DLL_MFUN(video_height)
{
    Video * vid = (Video *) OBJ_MEMBER_INT(SELF, video_data_offset);
    RETURN->v_int = vid->height;
}

CK_DLL_MFUN(video_pixel)
{
    Video * vid = (Video *) OBJ_MEMBER_INT(SELF, video_data_offset);
    
    t_CKINT x = GET_NEXT_INT(ARGS);
    t_CKINT y = GET_NEXT_INT(ARGS);
    
    // fprintf(stderr, "x: %li y: %li\n", x, y);
    
    if(vid->conv_pixels && x >= 0 && x < vid->width && y >= 0 && y < vid->height)
        RETURN->v_int = vid->conv_pixels[y*vid->width+x];
    else
        RETURN->v_int = 0;
}

inline float window(float dist, float width)
{
    if(dist < width)
    {
        //return cosf(M_PI/2.0f*(dist/width)); // cosine window
        return 1-fabsf(dist/width); // triangle window
    }
    else
    {
        return 0;
    }
}

inline void get_components(int pix, t_CKINT &r, t_CKINT &g, t_CKINT &b)
{
    b = ((pix>> 0)&0xFF);
    g = ((pix>> 8)&0xFF);
    r = ((pix>>16)&0xFF);
}

inline int set_components(t_CKINT r, t_CKINT g, t_CKINT b)
{
    int pix = 0;
    
    pix |= (r&0xFF)<<16;
    pix |= (g&0xFF)<< 8;
    pix |= (b&0xFF)<< 0;
    
    return pix;
}

CK_DLL_MFUN(video_pixelWithRadius)
{
    Video * vid = (Video *) OBJ_MEMBER_INT(SELF, video_data_offset);
    
    t_CKINT x = GET_NEXT_INT(ARGS);
    t_CKINT y = GET_NEXT_INT(ARGS);
    t_CKINT radius = GET_NEXT_INT(ARGS);
    t_CKINT radius_sq = radius*radius;
    // fprintf(stderr, "x: %li y: %li\n", x, y);
    
    if(vid->pixels && x >= 0 && x < vid->width && y >= 0 && y < vid->height)
    {
        t_CKINT r, g, b;
        t_CKFLOAT num;
        get_components(vid->pixels[y*vid->width+x], r, g, b);
        
        for(int x2 = x-radius; x2 < x+radius; x2 += 2)
        {
            for(int y2 = y-radius; y2 < y+radius; y2 += 2)
            {
                if(x2 >= 0 && x2 < vid->width && y2 >= 0 && y2 < vid->height)
                {
                    int distsq = (x-x2)*(x-x2) + (y-y2)*(y-y2);
                    if(distsq < radius_sq)
                    {
                        float dist = sqrtf(distsq);
                        t_CKINT r2, g2, b2;
                        get_components(vid->pixels[y2*vid->width+x2], r2, g2, b2);
                        float alpha = window(dist, radius);
                        r += alpha*r2;
                        g += alpha*g2;
                        b += alpha*b2;
                        num += alpha;
                    }
                }
            }
        }
        
        RETURN->v_int = set_components(r/num, g/num, b/num);
    }
    else
        RETURN->v_int = 0;
}

CK_DLL_QUERY( Video )
{
    QUERY->setname(QUERY, "Video");
    
    QUERY->begin_class(QUERY, "Video", "Object");

    QUERY->add_ctor(QUERY, video_ctor);
    QUERY->add_dtor(QUERY, video_dtor);
    
    QUERY->add_mfun(QUERY, video_open, "int", "open");
    
    QUERY->add_mfun(QUERY, video_openNamed, "int", "open");
    QUERY->add_arg(QUERY, "string", "arg");
    
    QUERY->add_mfun(QUERY, video_width, "int", "width");
    
    QUERY->add_mfun(QUERY, video_height, "int", "height");

    QUERY->add_mfun(QUERY, video_pixel, "int", "pixel");
    QUERY->add_arg(QUERY, "int", "x");
    QUERY->add_arg(QUERY, "int", "y");
    
    QUERY->add_mfun(QUERY, video_pixelWithRadius, "int", "pixel");
    QUERY->add_arg(QUERY, "int", "x");
    QUERY->add_arg(QUERY, "int", "y");
    QUERY->add_arg(QUERY, "int", "radius");
    
    video_data_offset = QUERY->add_mvar(QUERY, "int", "@vid_data", false);

    QUERY->end_class(QUERY);

    return TRUE;
}



