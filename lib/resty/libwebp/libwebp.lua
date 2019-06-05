local ffi = require('ffi')
ffi.cdef[[
///////DECODE//////////////
typedef struct WebPRGBABuffer WebPRGBABuffer;
typedef struct WebPYUVABuffer WebPYUVABuffer;
typedef struct WebPDecBuffer WebPDecBuffer;
typedef struct WebPIDecoder WebPIDecoder;
typedef struct WebPBitstreamFeatures WebPBitstreamFeatures;
typedef struct WebPDecoderOptions WebPDecoderOptions;
typedef struct WebPDecoderConfig WebPDecoderConfig;

// Return the decoder's version number, packed in hexadecimal using 8bits for
// each of major/minor/revision. E.g: v2.5.7 is 0x020507.
extern int WebPGetDecoderVersion(void);

// Retrieve basic header information: width, height.
// This function will also validate the header, returning true on success,
// false otherwise. '*width' and '*height' are only valid on successful return.
// Pointers 'width' and 'height' can be passed NULL if deemed irrelevant.
// Note: The following chunk sequences (before the raw VP8/VP8L data) are
// considered valid by this function:
// RIFF + VP8(L)
// RIFF + VP8X + (optional chunks) + VP8(L)
// ALPH + VP8 <-- Not a valid WebP format: only allowed for internal purpose.
// VP8(L)     <-- Not a valid WebP format: only allowed for internal purpose.
extern int WebPGetInfo(const uint8_t* data, size_t data_size,
                            int* width, int* height);

// Decodes WebP images pointed to by 'data' and returns RGBA samples, along
// with the dimensions in *width and *height. The ordering of samples in
// memory is R, G, B, A, R, G, B, A... in scan order (endian-independent).
// The returned pointer should be deleted calling WebPFree().
// Returns NULL in case of error.
extern uint8_t* WebPDecodeRGBA(const uint8_t* data, size_t data_size,
                                    int* width, int* height);

// Same as WebPDecodeRGBA, but returning A, R, G, B, A, R, G, B... ordered data.
extern uint8_t* WebPDecodeARGB(const uint8_t* data, size_t data_size,
                                    int* width, int* height);

// Same as WebPDecodeRGBA, but returning B, G, R, A, B, G, R, A... ordered data.
extern uint8_t* WebPDecodeBGRA(const uint8_t* data, size_t data_size,
                                    int* width, int* height);

// Same as WebPDecodeRGBA, but returning R, G, B, R, G, B... ordered data.
// If the bitstream contains transparency, it is ignored.
extern uint8_t* WebPDecodeRGB(const uint8_t* data, size_t data_size,
                                   int* width, int* height);

// Same as WebPDecodeRGB, but returning B, G, R, B, G, R... ordered data.
extern uint8_t* WebPDecodeBGR(const uint8_t* data, size_t data_size,
                                   int* width, int* height);


// Decode WebP images pointed to by 'data' to Y'UV format(*). The pointer
// returned is the Y samples buffer. Upon return, *u and *v will point to
// the U and V chroma data. These U and V buffers need NOT be passed to
// WebPFree(), unlike the returned Y luma one. The dimension of the U and V
// planes are both (*width + 1) / 2 and (*height + 1)/ 2.
// Upon return, the Y buffer has a stride returned as '*stride', while U and V
// have a common stride returned as '*uv_stride'.
// Return NULL in case of error.
// (*) Also named Y'CbCr. See: http://en.wikipedia.org/wiki/YCbCr
extern uint8_t* WebPDecodeYUV(const uint8_t* data, size_t data_size,
                                   int* width, int* height,
                                   uint8_t** u, uint8_t** v,
                                   int* stride, int* uv_stride);

// Releases memory returned by the WebPDecode*() functions above.
extern void WebPFree(void* ptr);

// These five functions are variants of the above ones, that decode the image
// directly into a pre-allocated buffer 'output_buffer'. The maximum storage
// available in this buffer is indicated by 'output_buffer_size'. If this
// storage is not sufficient (or an error occurred), NULL is returned.
// Otherwise, output_buffer is returned, for convenience.
// The parameter 'output_stride' specifies the distance (in bytes)
// between scanlines. Hence, output_buffer_size is expected to be at least
// output_stride x picture-height.
extern uint8_t* WebPDecodeRGBAInto(
    const uint8_t* data, size_t data_size,
    uint8_t* output_buffer, size_t output_buffer_size, int output_stride);
extern uint8_t* WebPDecodeARGBInto(
    const uint8_t* data, size_t data_size,
    uint8_t* output_buffer, size_t output_buffer_size, int output_stride);
extern uint8_t* WebPDecodeBGRAInto(
    const uint8_t* data, size_t data_size,
    uint8_t* output_buffer, size_t output_buffer_size, int output_stride);

// RGB and BGR variants. Here too the transparency information, if present,
// will be dropped and ignored.
extern uint8_t* WebPDecodeRGBInto(
    const uint8_t* data, size_t data_size,
    uint8_t* output_buffer, size_t output_buffer_size, int output_stride);
extern uint8_t* WebPDecodeBGRInto(
    const uint8_t* data, size_t data_size,
    uint8_t* output_buffer, size_t output_buffer_size, int output_stride);

// WebPDecodeYUVInto() is a variant of WebPDecodeYUV() that operates directly
// into pre-allocated luma/chroma plane buffers. This function requires the
// strides to be passed: one for the luma plane and one for each of the
// chroma ones. The size of each plane buffer is passed as 'luma_size',
// 'u_size' and 'v_size' respectively.
// Pointer to the luma plane ('*luma') is returned or NULL if an error occurred
// during decoding (or because some buffers were found to be too small).
extern uint8_t* WebPDecodeYUVInto(
    const uint8_t* data, size_t data_size,
    uint8_t* luma, size_t luma_size, int luma_stride,
    uint8_t* u, size_t u_size, int u_stride,
    uint8_t* v, size_t v_size, int v_stride);

//------------------------------------------------------------------------------
// Output colorspaces and buffer

// Colorspaces
// Note: the naming describes the byte-ordering of packed samples in memory.
// For instance, MODE_BGRA relates to samples ordered as B,G,R,A,B,G,R,A,...
// Non-capital names (e.g.:MODE_Argb) relates to pre-multiplied RGB channels.
// RGBA-4444 and RGB-565 colorspaces are represented by following byte-order:
// RGBA-4444: [r3 r2 r1 r0 g3 g2 g1 g0], [b3 b2 b1 b0 a3 a2 a1 a0], ...
// RGB-565: [r4 r3 r2 r1 r0 g5 g4 g3], [g2 g1 g0 b4 b3 b2 b1 b0], ...
// In the case WEBP_SWAP_16BITS_CSP is defined, the bytes are swapped for
// these two modes:
// RGBA-4444: [b3 b2 b1 b0 a3 a2 a1 a0], [r3 r2 r1 r0 g3 g2 g1 g0], ...
// RGB-565: [g2 g1 g0 b4 b3 b2 b1 b0], [r4 r3 r2 r1 r0 g5 g4 g3], ...

typedef enum WEBP_CSP_MODE {
  MODE_RGB = 0, MODE_RGBA = 1,
  MODE_BGR = 2, MODE_BGRA = 3,
  MODE_ARGB = 4, MODE_RGBA_4444 = 5,
  MODE_RGB_565 = 6,
  // RGB-premultiplied transparent modes (alpha value is preserved)
  MODE_rgbA = 7,
  MODE_bgrA = 8,
  MODE_Argb = 9,
  MODE_rgbA_4444 = 10,
  // YUV modes must come after RGB ones.
  MODE_YUV = 11, MODE_YUVA = 12,  // yuv 4:2:0
  MODE_LAST = 13
} WEBP_CSP_MODE;

//------------------------------------------------------------------------------
// WebPDecBuffer: Generic structure for describing the output sample buffer.

struct WebPRGBABuffer {    // view as RGBA
  uint8_t* rgba;    // pointer to RGBA samples
  int stride;       // stride in bytes from one scanline to the next.
  size_t size;      // total size of the *rgba buffer.
};

struct WebPYUVABuffer {              // view as YUVA
  uint8_t* y, *u, *v, *a;     // pointer to luma, chroma U/V, alpha samples
  int y_stride;               // luma stride
  int u_stride, v_stride;     // chroma strides
  int a_stride;               // alpha stride
  size_t y_size;              // luma plane size
  size_t u_size, v_size;      // chroma planes size
  size_t a_size;              // alpha-plane size
};

// Output buffer
struct WebPDecBuffer {
  WEBP_CSP_MODE colorspace;  // Colorspace.
  int width, height;         // Dimensions.
  int is_external_memory;    // If non-zero, 'internal_memory' pointer is not
                             // used. If value is '2' or more, the external
                             // memory is considered 'slow' and multiple
                             // read/write will be avoided.
  union {
    WebPRGBABuffer RGBA;
    WebPYUVABuffer YUVA;
  } u;                       // Nameless union of buffer parameters.
  uint32_t       pad[4];     // padding for later use

  uint8_t* private_memory;   // Internally allocated memory (only when
                             // is_external_memory is 0). Should not be used
                             // externally, but accessed via the buffer union.
};

// Internal, version-checked, entry point
extern int WebPInitDecBufferInternal(WebPDecBuffer*, int);

// Free any memory associated with the buffer. Must always be called last.
// Note: doesn't free the 'buffer' structure itself.
extern void WebPFreeDecBuffer(WebPDecBuffer* buffer);

//------------------------------------------------------------------------------
// Enumeration of the status codes

typedef enum VP8StatusCode {
  VP8_STATUS_OK = 0,
  VP8_STATUS_OUT_OF_MEMORY,
  VP8_STATUS_INVALID_PARAM,
  VP8_STATUS_BITSTREAM_ERROR,
  VP8_STATUS_UNSUPPORTED_FEATURE,
  VP8_STATUS_SUSPENDED,
  VP8_STATUS_USER_ABORT,
  VP8_STATUS_NOT_ENOUGH_DATA
} VP8StatusCode;

//------------------------------------------------------------------------------
// Incremental decoding
//
// This API allows streamlined decoding of partial data.
// Picture can be incrementally decoded as data become available thanks to the
// WebPIDecoder object. This object can be left in a SUSPENDED state if the
// picture is only partially decoded, pending additional input.
// Code example:
//
//   WebPInitDecBuffer(&output_buffer);
//   output_buffer.colorspace = mode;
//   ...
//   WebPIDecoder* idec = WebPINewDecoder(&output_buffer);
//   while (additional_data_is_available) {
//     // ... (get additional data in some new_data[] buffer)
//     status = WebPIAppend(idec, new_data, new_data_size);
//     if (status != VP8_STATUS_OK && status != VP8_STATUS_SUSPENDED) {
//       break;    // an error occurred.
//     }
//
//     // The above call decodes the current available buffer.
//     // Part of the image can now be refreshed by calling
//     // WebPIDecGetRGB()/WebPIDecGetYUVA() etc.
//   }
//   WebPIDelete(idec);

// Creates a new incremental decoder with the supplied buffer parameter.
// This output_buffer can be passed NULL, in which case a default output buffer
// is used (with MODE_RGB). Otherwise, an internal reference to 'output_buffer'
// is kept, which means that the lifespan of 'output_buffer' must be larger than
// that of the returned WebPIDecoder object.
// The supplied 'output_buffer' content MUST NOT be changed between calls to
// WebPIAppend() or WebPIUpdate() unless 'output_buffer.is_external_memory' is
// not set to 0. In such a case, it is allowed to modify the pointers, size and
// stride of output_buffer.u.RGBA or output_buffer.u.YUVA, provided they remain
// within valid bounds.
// All other fields of WebPDecBuffer MUST remain constant between calls.
// Returns NULL if the allocation failed.
extern WebPIDecoder* WebPINewDecoder(WebPDecBuffer* output_buffer);

// This function allocates and initializes an incremental-decoder object, which
// will output the RGB/A samples specified by 'csp' into a preallocated
// buffer 'output_buffer'. The size of this buffer is at least
// 'output_buffer_size' and the stride (distance in bytes between two scanlines)
// is specified by 'output_stride'.
// Additionally, output_buffer can be passed NULL in which case the output
// buffer will be allocated automatically when the decoding starts. The
// colorspace 'csp' is taken into account for allocating this buffer. All other
// parameters are ignored.
// Returns NULL if the allocation failed, or if some parameters are invalid.
extern WebPIDecoder* WebPINewRGB(
    WEBP_CSP_MODE csp,
    uint8_t* output_buffer, size_t output_buffer_size, int output_stride);

// This function allocates and initializes an incremental-decoder object, which
// will output the raw luma/chroma samples into a preallocated planes if
// supplied. The luma plane is specified by its pointer 'luma', its size
// 'luma_size' and its stride 'luma_stride'. Similarly, the chroma-u plane
// is specified by the 'u', 'u_size' and 'u_stride' parameters, and the chroma-v
// plane by 'v' and 'v_size'. And same for the alpha-plane. The 'a' pointer
// can be pass NULL in case one is not interested in the transparency plane.
// Conversely, 'luma' can be passed NULL if no preallocated planes are supplied.
// In this case, the output buffer will be automatically allocated (using
// MODE_YUVA) when decoding starts. All parameters are then ignored.
// Returns NULL if the allocation failed or if a parameter is invalid.
extern WebPIDecoder* WebPINewYUVA(
    uint8_t* luma, size_t luma_size, int luma_stride,
    uint8_t* u, size_t u_size, int u_stride,
    uint8_t* v, size_t v_size, int v_stride,
    uint8_t* a, size_t a_size, int a_stride);

// Deprecated version of the above, without the alpha plane.
// Kept for backward compatibility.
extern WebPIDecoder* WebPINewYUV(
    uint8_t* luma, size_t luma_size, int luma_stride,
    uint8_t* u, size_t u_size, int u_stride,
    uint8_t* v, size_t v_size, int v_stride);

// Deletes the WebPIDecoder object and associated memory. Must always be called
// if WebPINewDecoder, WebPINewRGB or WebPINewYUV succeeded.
extern void WebPIDelete(WebPIDecoder* idec);

// Copies and decodes the next available data. Returns VP8_STATUS_OK when
// the image is successfully decoded. Returns VP8_STATUS_SUSPENDED when more
// data is expected. Returns error in other cases.
extern VP8StatusCode WebPIAppend(
    WebPIDecoder* idec, const uint8_t* data, size_t data_size);

// A variant of the above function to be used when data buffer contains
// partial data from the beginning. In this case data buffer is not copied
// to the internal memory.
// Note that the value of the 'data' pointer can change between calls to
// WebPIUpdate, for instance when the data buffer is resized to fit larger data.
extern VP8StatusCode WebPIUpdate(
    WebPIDecoder* idec, const uint8_t* data, size_t data_size);

// Returns the RGB/A image decoded so far. Returns NULL if output params
// are not initialized yet. The RGB/A output type corresponds to the colorspace
// specified during call to WebPINewDecoder() or WebPINewRGB().
// *last_y is the index of last decoded row in raster scan order. Some pointers
// (*last_y, *width etc.) can be NULL if corresponding information is not
// needed. The values in these pointers are only valid on successful (non-NULL)
// return.
extern uint8_t* WebPIDecGetRGB(
    const WebPIDecoder* idec, int* last_y,
    int* width, int* height, int* stride);

// Same as above function to get a YUVA image. Returns pointer to the luma
// plane or NULL in case of error. If there is no alpha information
// the alpha pointer '*a' will be returned NULL.
extern uint8_t* WebPIDecGetYUVA(
    const WebPIDecoder* idec, int* last_y,
    uint8_t** u, uint8_t** v, uint8_t** a,
    int* width, int* height, int* stride, int* uv_stride, int* a_stride);


// Generic call to retrieve information about the displayable area.
// If non NULL, the left/right/width/height pointers are filled with the visible
// rectangular area so far.
// Returns NULL in case the incremental decoder object is in an invalid state.
// Otherwise returns the pointer to the internal representation. This structure
// is read-only, tied to WebPIDecoder's lifespan and should not be modified.
extern const WebPDecBuffer* WebPIDecodedArea(
    const WebPIDecoder* idec, int* left, int* top, int* width, int* height);

//------------------------------------------------------------------------------
// Advanced decoding parametrization
//
//  Code sample for using the advanced decoding API
/*
     // A) Init a configuration object
     WebPDecoderConfig config;
     CHECK(WebPInitDecoderConfig(&config));

     // B) optional: retrieve the bitstream's features.
     CHECK(WebPGetFeatures(data, data_size, &config.input) == VP8_STATUS_OK);

     // C) Adjust 'config', if needed
     config.no_fancy_upsampling = 1;
     config.output.colorspace = MODE_BGRA;
     // etc.

     // Note that you can also make config.output point to an externally
     // supplied memory buffer, provided it's big enough to store the decoded
     // picture. Otherwise, config.output will just be used to allocate memory
     // and store the decoded picture.

     // D) Decode!
     CHECK(WebPDecode(data, data_size, &config) == VP8_STATUS_OK);

     // E) Decoded image is now in config.output (and config.output.u.RGBA)

     // F) Reclaim memory allocated in config's object. It's safe to call
     // this function even if the memory is external and wasn't allocated
     // by WebPDecode().
     WebPFreeDecBuffer(&config.output);
*/

// Features gathered from the bitstream
struct WebPBitstreamFeatures {
  int width;          // Width in pixels, as read from the bitstream.
  int height;         // Height in pixels, as read from the bitstream.
  int has_alpha;      // True if the bitstream contains an alpha channel.
  int has_animation;  // True if the bitstream is an animation.
  int format;         // 0 = undefined (/mixed), 1 = lossy, 2 = lossless

  uint32_t pad[5];    // padding for later use
};

// Internal, version-checked, entry point
extern VP8StatusCode WebPGetFeaturesInternal(
    const uint8_t*, size_t, WebPBitstreamFeatures*, int);

// Decoding options
struct WebPDecoderOptions {
  int bypass_filtering;               // if true, skip the in-loop filtering
  int no_fancy_upsampling;            // if true, use faster pointwise upsampler
  int use_cropping;                   // if true, cropping is applied _first_
  int crop_left, crop_top;            // top-left position for cropping.
                                      // Will be snapped to even values.
  int crop_width, crop_height;        // dimension of the cropping area
  int use_scaling;                    // if true, scaling is applied _afterward_
  int scaled_width, scaled_height;    // final resolution
  int use_threads;                    // if true, use multi-threaded decoding
  int dithering_strength;             // dithering strength (0=Off, 100=full)
  int flip;                           // flip output vertically
  int alpha_dithering_strength;       // alpha dithering strength in [0..100]

  uint32_t pad[5];                    // padding for later use
};

// Main object storing the configuration for advanced decoding.
struct WebPDecoderConfig {
  WebPBitstreamFeatures input;  // Immutable bitstream features (optional)
  WebPDecBuffer output;         // Output buffer (can point to external mem)
  WebPDecoderOptions options;   // Decoding options
};

// Internal, version-checked, entry point
extern int WebPInitDecoderConfigInternal(WebPDecoderConfig*, int);


// Instantiate a new incremental decoder object with the requested
// configuration. The bitstream can be passed using 'data' and 'data_size'
// parameter, in which case the features will be parsed and stored into
// config->input. Otherwise, 'data' can be NULL and no parsing will occur.
// Note that 'config' can be NULL too, in which case a default configuration
// is used. If 'config' is not NULL, it must outlive the WebPIDecoder object
// as some references to its fields will be used. No internal copy of 'config'
// is made.
// The return WebPIDecoder object must always be deleted calling WebPIDelete().
// Returns NULL in case of error (and config->status will then reflect
// the error condition, if available).
extern WebPIDecoder* WebPIDecode(const uint8_t* data, size_t data_size,
                                      WebPDecoderConfig* config);

// Non-incremental version. This version decodes the full data at once, taking
// 'config' into account. Returns decoding status (which should be VP8_STATUS_OK
// if the decoding was successful). Note that 'config' cannot be NULL.
extern VP8StatusCode WebPDecode(const uint8_t* data, size_t data_size,
                                     WebPDecoderConfig* config);


//////////////////ENCODE//////////////////////

typedef struct WebPConfig WebPConfig;
typedef struct WebPPicture WebPPicture;   // main structure for I/O
typedef struct WebPAuxStats WebPAuxStats;
typedef struct WebPMemoryWriter WebPMemoryWriter;

// Return the encoder's version number, packed in hexadecimal using 8bits for
// each of major/minor/revision. E.g: v2.5.7 is 0x020507.
extern int WebPGetEncoderVersion(void);

//------------------------------------------------------------------------------
// One-stop-shop call! No questions asked:

// Returns the size of the compressed data (pointed to by *output), or 0 if
// an error occurred. The compressed data must be released by the caller
// using the call 'WebPFree(*output)'.
// These functions compress using the lossy format, and the quality_factor
// can go from 0 (smaller output, lower quality) to 100 (best quality,
// larger output).
extern size_t WebPEncodeRGB(const uint8_t* rgb,
                                 int width, int height, int stride,
                                 float quality_factor, uint8_t** output);
extern size_t WebPEncodeBGR(const uint8_t* bgr,
                                 int width, int height, int stride,
                                 float quality_factor, uint8_t** output);
extern size_t WebPEncodeRGBA(const uint8_t* rgba,
                                  int width, int height, int stride,
                                  float quality_factor, uint8_t** output);
extern size_t WebPEncodeBGRA(const uint8_t* bgra,
                                  int width, int height, int stride,
                                  float quality_factor, uint8_t** output);

// These functions are the equivalent of the above, but compressing in a
// lossless manner. Files are usually larger than lossy format, but will
// not suffer any compression loss.
extern size_t WebPEncodeLosslessRGB(const uint8_t* rgb,
                                         int width, int height, int stride,
                                         uint8_t** output);
extern size_t WebPEncodeLosslessBGR(const uint8_t* bgr,
                                         int width, int height, int stride,
                                         uint8_t** output);
extern size_t WebPEncodeLosslessRGBA(const uint8_t* rgba,
                                          int width, int height, int stride,
                                          uint8_t** output);
extern size_t WebPEncodeLosslessBGRA(const uint8_t* bgra,
                                          int width, int height, int stride,
                                          uint8_t** output);

// Releases memory returned by the WebPEncode*() functions above.
extern void WebPFree(void* ptr);

//------------------------------------------------------------------------------
// Coding parameters

// Image characteristics hint for the underlying encoder.
typedef enum WebPImageHint {
  WEBP_HINT_DEFAULT = 0,  // default preset.
  WEBP_HINT_PICTURE,      // digital picture, like portrait, inner shot
  WEBP_HINT_PHOTO,        // outdoor photograph, with natural lighting
  WEBP_HINT_GRAPH,        // Discrete tone image (graph, map-tile etc).
  WEBP_HINT_LAST
} WebPImageHint;

// Compression parameters.
struct WebPConfig {
  int lossless;           // Lossless encoding (0=lossy(default), 1=lossless).
  float quality;          // between 0 and 100. For lossy, 0 gives the smallest
                          // size and 100 the largest. For lossless, this
                          // parameter is the amount of effort put into the
                          // compression: 0 is the fastest but gives larger
                          // files compared to the slowest, but best, 100.
  int method;             // quality/speed trade-off (0=fast, 6=slower-better)

  WebPImageHint image_hint;  // Hint for image type (lossless only for now).

  int target_size;        // if non-zero, set the desired target size in bytes.
                          // Takes precedence over the 'compression' parameter.
  float target_PSNR;      // if non-zero, specifies the minimal distortion to
                          // try to achieve. Takes precedence over target_size.
  int segments;           // maximum number of segments to use, in [1..4]
  int sns_strength;       // Spatial Noise Shaping. 0=off, 100=maximum.
  int filter_strength;    // range: [0 = off .. 100 = strongest]
  int filter_sharpness;   // range: [0 = off .. 7 = least sharp]
  int filter_type;        // filtering type: 0 = simple, 1 = strong (only used
                          // if filter_strength > 0 or autofilter > 0)
  int autofilter;         // Auto adjust filter's strength [0 = off, 1 = on]
  int alpha_compression;  // Algorithm for encoding the alpha plane (0 = none,
                          // 1 = compressed with WebP lossless). Default is 1.
  int alpha_filtering;    // Predictive filtering method for alpha plane.
                          //  0: none, 1: fast, 2: best. Default if 1.
  int alpha_quality;      // Between 0 (smallest size) and 100 (lossless).
                          // Default is 100.
  int pass;               // number of entropy-analysis passes (in [1..10]).

  int show_compressed;    // if true, export the compressed picture back.
                          // In-loop filtering is not applied.
  int preprocessing;      // preprocessing filter:
                          // 0=none, 1=segment-smooth, 2=pseudo-random dithering
  int partitions;         // log2(number of token partitions) in [0..3]. Default
                          // is set to 0 for easier progressive decoding.
  int partition_limit;    // quality degradation allowed to fit the 512k limit
                          // on prediction modes coding (0: no degradation,
                          // 100: maximum possible degradation).
  int emulate_jpeg_size;  // If true, compression parameters will be remapped
                          // to better match the expected output size from
                          // JPEG compression. Generally, the output size will
                          // be similar but the degradation will be lower.
  int thread_level;       // If non-zero, try and use multi-threaded encoding.
  int low_memory;         // If set, reduce memory usage (but increase CPU use).

  int near_lossless;      // Near lossless encoding [0 = max loss .. 100 = off
                          // (default)].
  int exact;              // if non-zero, preserve the exact RGB values under
                          // transparent area. Otherwise, discard this invisible
                          // RGB information for better compression. The default
                          // value is 0.

  int use_delta_palette;  // reserved for future lossless feature
  int use_sharp_yuv;      // if needed, use sharp (and slow) RGB->YUV conversion

  uint32_t pad[2];        // padding for later use
};

// Enumerate some predefined settings for WebPConfig, depending on the type
// of source picture. These presets are used when calling WebPConfigPreset().
typedef enum WebPPreset {
  WEBP_PRESET_DEFAULT = 0,  // default preset.
  WEBP_PRESET_PICTURE,      // digital picture, like portrait, inner shot
  WEBP_PRESET_PHOTO,        // outdoor photograph, with natural lighting
  WEBP_PRESET_DRAWING,      // hand or line drawing, with high-contrast details
  WEBP_PRESET_ICON,         // small-sized colorful images
  WEBP_PRESET_TEXT          // text-like
} WebPPreset;

// Internal, version-checked, entry point
extern int WebPConfigInitInternal(WebPConfig*, WebPPreset, float, int);


// Activate the lossless compression mode with the desired efficiency level
// between 0 (fastest, lowest compression) and 9 (slower, best compression).
// A good default level is '6', providing a fair tradeoff between compression
// speed and final compressed size.
// This function will overwrite several fields from config: 'method', 'quality'
// and 'lossless'. Returns false in case of parameter error.
extern int WebPConfigLosslessPreset(WebPConfig* config, int level);

// Returns true if 'config' is non-NULL and all configuration parameters are
// within their valid ranges.
extern int WebPValidateConfig(const WebPConfig* config);

//------------------------------------------------------------------------------
// Input / Output
// Structure for storing auxiliary statistics.

struct WebPAuxStats {
  int coded_size;         // final size

  float PSNR[5];          // peak-signal-to-noise ratio for Y/U/V/All/Alpha
  int block_count[3];     // number of intra4/intra16/skipped macroblocks
  int header_bytes[2];    // approximate number of bytes spent for header
                          // and mode-partition #0
  int residual_bytes[3][4];  // approximate number of bytes spent for
                             // DC/AC/uv coefficients for each (0..3) segments.
  int segment_size[4];    // number of macroblocks in each segments
  int segment_quant[4];   // quantizer values for each segments
  int segment_level[4];   // filtering strength for each segments [0..63]

  int alpha_data_size;    // size of the transparency data
  int layer_data_size;    // size of the enhancement layer data

  // lossless encoder statistics
  uint32_t lossless_features;  // bit0:predictor bit1:cross-color transform
                               // bit2:subtract-green bit3:color indexing
  int histogram_bits;          // number of precision bits of histogram
  int transform_bits;          // precision bits for transform
  int cache_bits;              // number of bits for color cache lookup
  int palette_size;            // number of color in palette, if used
  int lossless_size;           // final lossless size
  int lossless_hdr_size;       // lossless header (transform, huffman etc) size
  int lossless_data_size;      // lossless image data size

  uint32_t pad[2];        // padding for later use
};

// Signature for output function. Should return true if writing was successful.
// data/data_size is the segment of data to write, and 'picture' is for
// reference (and so one can make use of picture->custom_ptr).
typedef int (*WebPWriterFunction)(const uint8_t* data, size_t data_size,
                                  const WebPPicture* picture);

// WebPMemoryWrite: a special WebPWriterFunction that writes to memory using
// the following WebPMemoryWriter object (to be set as a custom_ptr).
struct WebPMemoryWriter {
  uint8_t* mem;       // final buffer (of size 'max_size', larger than 'size').
  size_t   size;      // final size
  size_t   max_size;  // total capacity
  uint32_t pad[1];    // padding for later use
};

// The following must be called first before any use.
extern void WebPMemoryWriterInit(WebPMemoryWriter* writer);

// The following must be called to deallocate writer->mem memory. The 'writer'
// object itself is not deallocated.
extern void WebPMemoryWriterClear(WebPMemoryWriter* writer);
// The custom writer to be used with WebPMemoryWriter as custom_ptr. Upon
// completion, writer.mem and writer.size will hold the coded data.
// writer.mem must be freed by calling WebPMemoryWriterClear.
extern int WebPMemoryWrite(const uint8_t* data, size_t data_size,
                                const WebPPicture* picture);

// Progress hook, called from time to time to report progress. It can return
// false to request an abort of the encoding process, or true otherwise if
// everything is OK.
typedef int (*WebPProgressHook)(int percent, const WebPPicture* picture);

// Color spaces.
typedef enum WebPEncCSP {
  // chroma sampling
  WEBP_YUV420  = 0,        // 4:2:0
  WEBP_YUV420A = 4,        // alpha channel variant
  WEBP_CSP_UV_MASK = 3,    // bit-mask to get the UV sampling factors
  WEBP_CSP_ALPHA_BIT = 4   // bit that is set if alpha is present
} WebPEncCSP;

// Encoding error conditions.
typedef enum WebPEncodingError {
  VP8_ENC_OK = 0,
  VP8_ENC_ERROR_OUT_OF_MEMORY,            // memory error allocating objects
  VP8_ENC_ERROR_BITSTREAM_OUT_OF_MEMORY,  // memory error while flushing bits
  VP8_ENC_ERROR_NULL_PARAMETER,           // a pointer parameter is NULL
  VP8_ENC_ERROR_INVALID_CONFIGURATION,    // configuration is invalid
  VP8_ENC_ERROR_BAD_DIMENSION,            // picture has invalid width/height
  VP8_ENC_ERROR_PARTITION0_OVERFLOW,      // partition is bigger than 512k
  VP8_ENC_ERROR_PARTITION_OVERFLOW,       // partition is bigger than 16M
  VP8_ENC_ERROR_BAD_WRITE,                // error while flushing bytes
  VP8_ENC_ERROR_FILE_TOO_BIG,             // file is bigger than 4G
  VP8_ENC_ERROR_USER_ABORT,               // abort request by user
  VP8_ENC_ERROR_LAST                      // list terminator. always last.
} WebPEncodingError;

// Main exchange structure (input samples, output bytes, statistics)
struct WebPPicture {
  //   INPUT
  //////////////
  // Main flag for encoder selecting between ARGB or YUV input.
  // It is recommended to use ARGB input (*argb, argb_stride) for lossless
  // compression, and YUV input (*y, *u, *v, etc.) for lossy compression
  // since these are the respective native colorspace for these formats.
  int use_argb;

  // YUV input (mostly used for input to lossy compression)
  WebPEncCSP colorspace;     // colorspace: should be YUV420 for now (=Y'CbCr).
  int width, height;         // dimensions (less or equal to 16383)
  uint8_t *y, *u, *v;        // pointers to luma/chroma planes.
  int y_stride, uv_stride;   // luma/chroma strides.
  uint8_t* a;                // pointer to the alpha plane
  int a_stride;              // stride of the alpha plane
  uint32_t pad1[2];          // padding for later use

  // ARGB input (mostly used for input to lossless compression)
  uint32_t* argb;            // Pointer to argb (32 bit) plane.
  int argb_stride;           // This is stride in pixels units, not bytes.
  uint32_t pad2[3];          // padding for later use

  //   OUTPUT
  ///////////////
  // Byte-emission hook, to store compressed bytes as they are ready.
  WebPWriterFunction writer;  // can be NULL
  void* custom_ptr;           // can be used by the writer.

  // map for extra information (only for lossy compression mode)
  int extra_info_type;    // 1: intra type, 2: segment, 3: quant
                          // 4: intra-16 prediction mode,
                          // 5: chroma prediction mode,
                          // 6: bit cost, 7: distortion
  uint8_t* extra_info;    // if not NULL, points to an array of size
                          // ((width + 15) / 16) * ((height + 15) / 16) that
                          // will be filled with a macroblock map, depending
                          // on extra_info_type.

  //   STATS AND REPORTS
  ///////////////////////////
  // Pointer to side statistics (updated only if not NULL)
  WebPAuxStats* stats;

  // Error code for the latest error encountered during encoding
  WebPEncodingError error_code;

  // If not NULL, report progress during encoding.
  WebPProgressHook progress_hook;

  void* user_data;        // this field is free to be set to any value and
                          // used during callbacks (like progress-report e.g.).

  uint32_t pad3[3];       // padding for later use

  // Unused for now
  uint8_t *pad4, *pad5;
  uint32_t pad6[8];       // padding for later use

  // PRIVATE FIELDS
  ////////////////////
  void* memory_;          // row chunk of memory for yuva planes
  void* memory_argb_;     // and for argb too.
  void* pad7[2];          // padding for later use
};

// Internal, version-checked, entry point
extern int WebPPictureInitInternal(WebPPicture*, int);


//------------------------------------------------------------------------------
// WebPPicture utils

// Convenience allocation / deallocation based on picture->width/height:
// Allocate y/u/v buffers as per colorspace/width/height specification.
// Note! This function will free the previous buffer if needed.
// Returns false in case of memory error.
extern int WebPPictureAlloc(WebPPicture* picture);

// Release the memory allocated by WebPPictureAlloc() or WebPPictureImport*().
// Note that this function does _not_ free the memory used by the 'picture'
// object itself.
// Besides memory (which is reclaimed) all other fields of 'picture' are
// preserved.
extern void WebPPictureFree(WebPPicture* picture);

// Copy the pixels of *src into *dst, using WebPPictureAlloc. Upon return, *dst
// will fully own the copied pixels (this is not a view). The 'dst' picture need
// not be initialized as its content is overwritten.
// Returns false in case of memory allocation error.
extern int WebPPictureCopy(const WebPPicture* src, WebPPicture* dst);

// Compute the single distortion for packed planes of samples.
// 'src' will be compared to 'ref', and the raw distortion stored into
// '*distortion'. The refined metric (log(MSE), log(1 - ssim),...' will be
// stored in '*result'.
// 'x_step' is the horizontal stride (in bytes) between samples.
// 'src/ref_stride' is the byte distance between rows.
// Returns false in case of error (bad parameter, memory allocation error, ...).
extern int WebPPlaneDistortion(const uint8_t* src, size_t src_stride,
                                    const uint8_t* ref, size_t ref_stride,
                                    int width, int height,
                                    size_t x_step,
                                    int type,   // 0 = PSNR, 1 = SSIM, 2 = LSIM
                                    float* distortion, float* result);

// Compute PSNR, SSIM or LSIM distortion metric between two pictures. Results
// are in dB, stored in result[] in the B/G/R/A/All order. The distortion is
// always performed using ARGB samples. Hence if the input is YUV(A), the
// picture will be internally converted to ARGB (just for the measurement).
// Warning: this function is rather CPU-intensive.
extern int WebPPictureDistortion(
    const WebPPicture* src, const WebPPicture* ref,
    int metric_type,           // 0 = PSNR, 1 = SSIM, 2 = LSIM
    float result[5]);

// self-crops a picture to the rectangle defined by top/left/width/height.
// Returns false in case of memory allocation error, or if the rectangle is
// outside of the source picture.
// The rectangle for the view is defined by the top-left corner pixel
// coordinates (left, top) as well as its width and height. This rectangle
// must be fully be comprised inside the 'src' source picture. If the source
// picture uses the YUV420 colorspace, the top and left coordinates will be
// snapped to even values.
extern int WebPPictureCrop(WebPPicture* picture,
                                int left, int top, int width, int height);

// Extracts a view from 'src' picture into 'dst'. The rectangle for the view
// is defined by the top-left corner pixel coordinates (left, top) as well
// as its width and height. This rectangle must be fully be comprised inside
// the 'src' source picture. If the source picture uses the YUV420 colorspace,
// the top and left coordinates will be snapped to even values.
// Picture 'src' must out-live 'dst' picture. Self-extraction of view is allowed
// ('src' equal to 'dst') as a mean of fast-cropping (but note that doing so,
// the original dimension will be lost). Picture 'dst' need not be initialized
// with WebPPictureInit() if it is different from 'src', since its content will
// be overwritten.
// Returns false in case of memory allocation error or invalid parameters.
extern int WebPPictureView(const WebPPicture* src,
                                int left, int top, int width, int height,
                                WebPPicture* dst);

// Returns true if the 'picture' is actually a view and therefore does
// not own the memory for pixels.
extern int WebPPictureIsView(const WebPPicture* picture);

// Rescale a picture to new dimension width x height.
// If either 'width' or 'height' (but not both) is 0 the corresponding
// dimension will be calculated preserving the aspect ratio.
// No gamma correction is applied.
// Returns false in case of error (invalid parameter or insufficient memory).
extern int WebPPictureRescale(WebPPicture* pic, int width, int height);

// Colorspace conversion function to import RGB samples.
// Previous buffer will be free'd, if any.
// *rgb buffer should have a size of at least height * rgb_stride.
// Returns false in case of memory error.
extern int WebPPictureImportRGB(
    WebPPicture* picture, const uint8_t* rgb, int rgb_stride);
// Same, but for RGBA buffer.
extern int WebPPictureImportRGBA(
    WebPPicture* picture, const uint8_t* rgba, int rgba_stride);
// Same, but for RGBA buffer. Imports the RGB direct from the 32-bit format
// input buffer ignoring the alpha channel. Avoids needing to copy the data
// to a temporary 24-bit RGB buffer to import the RGB only.
extern int WebPPictureImportRGBX(
    WebPPicture* picture, const uint8_t* rgbx, int rgbx_stride);

// Variants of the above, but taking BGR(A|X) input.
extern int WebPPictureImportBGR(
    WebPPicture* picture, const uint8_t* bgr, int bgr_stride);
extern int WebPPictureImportBGRA(
    WebPPicture* picture, const uint8_t* bgra, int bgra_stride);
extern int WebPPictureImportBGRX(
    WebPPicture* picture, const uint8_t* bgrx, int bgrx_stride);

// Converts picture->argb data to the YUV420A format. The 'colorspace'
// parameter is deprecated and should be equal to WEBP_YUV420.
// Upon return, picture->use_argb is set to false. The presence of real
// non-opaque transparent values is detected, and 'colorspace' will be
// adjusted accordingly. Note that this method is lossy.
// Returns false in case of error.
extern int WebPPictureARGBToYUVA(WebPPicture* picture,
                                      WebPEncCSP /*colorspace = WEBP_YUV420*/);

// Same as WebPPictureARGBToYUVA(), but the conversion is done using
// pseudo-random dithering with a strength 'dithering' between
// 0.0 (no dithering) and 1.0 (maximum dithering). This is useful
// for photographic picture.
extern int WebPPictureARGBToYUVADithered(
    WebPPicture* picture, WebPEncCSP colorspace, float dithering);

// Performs 'sharp' RGBA->YUVA420 downsampling and colorspace conversion.
// Downsampling is handled with extra care in case of color clipping. This
// method is roughly 2x slower than WebPPictureARGBToYUVA() but produces better
// and sharper YUV representation.
// Returns false in case of error.
extern int WebPPictureSharpARGBToYUVA(WebPPicture* picture);
// kept for backward compatibility:
extern int WebPPictureSmartARGBToYUVA(WebPPicture* picture);

// Converts picture->yuv to picture->argb and sets picture->use_argb to true.
// The input format must be YUV_420 or YUV_420A. The conversion from YUV420 to
// ARGB incurs a small loss too.
// Note that the use of this colorspace is discouraged if one has access to the
// raw ARGB samples, since using YUV420 is comparatively lossy.
// Returns false in case of error.
extern int WebPPictureYUVAToARGB(WebPPicture* picture);

// Helper function: given a width x height plane of RGBA or YUV(A) samples
// clean-up or smoothen the YUV or RGB samples under fully transparent area,
// to help compressibility (no guarantee, though).
extern void WebPCleanupTransparentArea(WebPPicture* picture);

// Scan the picture 'picture' for the presence of non fully opaque alpha values.
// Returns true in such case. Otherwise returns false (indicating that the
// alpha plane can be ignored altogether e.g.).
extern int WebPPictureHasTransparency(const WebPPicture* picture);

// Remove the transparency information (if present) by blending the color with
// the background color 'background_rgb' (specified as 24bit RGB triplet).
// After this call, all alpha values are reset to 0xff.
extern void WebPBlendAlpha(WebPPicture* pic, uint32_t background_rgb);

//------------------------------------------------------------------------------
// Main call

// Main encoding call, after config and picture have been initialized.
// 'picture' must be less than 16384x16384 in dimension (cf 16383),
// and the 'config' object must be a valid one.
// Returns false in case of error, true otherwise.
// In case of error, picture->error_code is updated accordingly.
// 'picture' can hold the source samples in both YUV(A) or ARGB input, depending
// on the value of 'picture->use_argb'. It is highly recommended to use
// the former for lossy encoding, and the latter for lossless encoding
// (when config.lossless is true). Automatic conversion from one format to
// another is provided but they both incur some loss.
extern int WebPEncode(const WebPConfig* config, WebPPicture* picture);



]]
--load from: https://developers.google.com/speed/webp/docs/compiling
local C = ffi.load('/usr/lib/libwebp.so')

return C
