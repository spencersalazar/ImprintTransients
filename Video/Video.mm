
// this should align with the correct versions of these ChucK files
#include "chuck_dl.h"
#include "chuck_def.h"

#include <CoreFoundation/CoreFoundation.h>
#include <CoreGraphics/CoreGraphics.h>
#include <AVFoundation/AVFoundation.h>

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
    Video() : pixels(NULL), width(0), height(0) { }
    
    ~Video()
    {
        [m_session stopRunning];
        [m_session release];
        m_session = nil;
    }
    
    t_CKBOOL open()
    {
        m_session = [AVCaptureSession new];
        // Set the session preset
        [m_session setSessionPreset:AVCaptureSessionPreset640x480];
        
        NSMutableArray *devices = [NSMutableArray array];
        for (AVCaptureDevice *device in [AVCaptureDevice devices])
        {
            if([device hasMediaType:AVMediaTypeVideo] || [device hasMediaType:AVMediaTypeMuxed])
                [devices addObject:device];
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
        
        return TRUE;
    }
    
    UInt32 *pixels;
    UInt32 width, height;
    
protected:
    AVCaptureSession *m_session;
    VideoBufferDelegate *m_delegate;
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
    
    UInt32 *pixels = _video->pixels;
    
    if(pixels == NULL)
    {
        NSLog(@"malloc %lu %lu", height*bytesPerRow, width*height*4);
        pixels = (UInt32 *) malloc(height*bytesPerRow);
    }
    
    memcpy(pixels, baseAddress, height*bytesPerRow);
    
    _video->width = width;
    _video->height = height;
    if(_video->pixels != pixels)
        _video->pixels = pixels;
    
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
    
    if(vid->pixels && x >= 0 && x < vid->width && y >= 0 && y < vid->height)
        RETURN->v_int = vid->pixels[y*vid->width+x];
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
    
    video_data_offset = QUERY->add_mvar(QUERY, "int", "@vid_data", false);

    QUERY->end_class(QUERY);

    return TRUE;
}



