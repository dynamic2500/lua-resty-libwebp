---
tagline: WEBP encoding & decoding
---

# Required Library
[libwebp](https://chromium.googlesource.com/webm/libwebp)

__Note__: After build library to "so" files, copy them to /usr/lib


## `local libwebp = require("resty.libwebp.webp")`

A ffi binding for the [libwebp](https://chromium.googlesource.com/webm/libwebp) with processing Webp image

## API
------------------------------------ -----------------------------------------
  * `libwebp.decompress.[opt]`                          set decode option, this option must be set before run load function
  * `libwebp.load_blob(blob) -> img:`               open a WEBP image from blob binary data for decoding
  * `libwebp.load_from_disk(<string>infile) -> img:`open a WEBP image from file on disk for decoding
  * `img.compress.[opt]:`                           set/read option for compress process (must set before run get_blob() for save() function)
  * `img:get_blob():`                               get WEBP image to binary string after compress
  * `img:save():`                                   save WEBP image to disk (must set img.compress.outfile)
------------------------------------ -----------------------------------------

### `libwebp.decompress.[opt]`

Set settings for decompress process. `opt` are some options as follow:
	* `bypass_filtering<boolean>`: if true, skip the in-loop filtering
	* `no_fancy_upsampling<boolean>`:  if true, use faster pointwise upsampler
	* `scaled_width<int>`: scale image to width pixel (keep aspect ratio)
	* `scaled_height<int>`: scale image to height pixel (keep aspect ratio)
	* `use_threads<boolean>`:  if true, use multi-threaded decoding
	* `dithering_strength<int>`: `0..100` range. = 0=off, 100=full
	* `alpha_dithering_strength<int>`: `0..100` range. Alpha dithering strength
	* `format`: RGB, RGBA, BRG, BRGA
	

### `libwebp.load_blob(blob) -> img`
### `libwebp.load_from_disk(infile) -> img`

Open a PNG image and read its header. `blob` is whole image binary string or `infile` is path to image file on disk

The return value is an image object which gives information about the file
and can be used to load and decode the actual pixels. It has the fields:

  * `w`, `h`: width and height of the image.

### `img.compress.[opt]`

Set settings for compress process. `opt` are some options as follow:


  * `lossless<int>` (default 0):            Lossless encoding (0=lossy(default), 1=lossless).
  * `quality<float>` (default 75):           between 0 and 100. For lossy, 0 gives the smallest
                           size and 100 the largest. For lossless, this
                           parameter is the amount of effort put into the
                           compression: 0 is the fastest but gives larger
  * `method<int>` (default 4):              quality/speed trade-off (0=fast, 6=slower-better)

  * `target_size<int>` (default 0):         if non-zero, set the desired target size in bytes.
                           Takes precedence over the 'compression' parameter.
  * `target_PSNR<float>` (default 0):       if non-zero, specifies the minimal distortion to
                           try to achieve. Takes precedence over target_size.
  * `segments<int>` (default 4):            maximum number of segments to use, in [1..4]
  * `sns_strength<int>` (default 50):        Spatial Noise Shaping. 0=off, 100=maximum.
  * `filter_strength<int>` (default 60):     range: [0 = off .. 100 = strongest]
  * `filter_sharpness<int>` (default 0):    range: [0 = off .. 7 = least sharp]
  * `filter_type<int>` (default 1):         filtering type: 0 = simple, 1 = strong (only used
                           if filter_strength > 0 or autofilter > 0)
  * `autofilter<int>` (default 0):          Auto adjust filter's strength [0 = off, 1 = on]
  * `alpha_compression<int>` (default 1):   Algorithm for encoding the alpha plane (0 = none,
                           1 = compressed with WebP lossless). Default is 1.
  * `alpha_filtering<int>` (default 1):     Predictive filtering method for alpha plane.
                            0: none, 1: fast, 2: best. Default if 1.
  * `alpha_quality<int>` (default 100):       Between 0 (smallest size) and 100 (lossless).
                           Default is 100.
  * `pass<int>` (default 1):                number of entropy-analysis passes (in [1..10]).

  * `show_compressed<int>` (default 0):     if true, export the compressed picture back.
                           In-loop filtering is not applied.
  * `preprocessing<int>` (default 0):       preprocessing filter:
                           0=none, 1=segment-smooth, 2=pseudo-random dithering
  * `partitions<int>` (default 0):          log2(number of token partitions) in [0..3]. Default
                           is set to 0 for easier progressive decoding.
  * `partition_limit<int>` (default 0):     quality degradation allowed to fit the 512k limit
                           on prediction modes coding (0: no degradation,
                           100: maximum possible degradation).
  * `emulate_jpeg_size<boolean>` (default false):   If true, compression parameters will be remapped
                           to better match the expected output size from
                           JPEG compression. Generally, the output size will
                           be similar but the degradation will be lower.
  * `thread_level<int>` (default 1):        If non-zero, try and use multi-threaded encoding.
  * `low_memory<int>` (default 0):          If set, reduce memory usage (but increase CPU use).

  * `near_lossless<int>` (default 100):       Near lossless encoding [0 = max loss .. 100 = off
                           (default)].
  * `exact<int>` (default 0):               if non-zero, preserve the exact RGB values under
                           transparent area. Otherwise, discard this invisible
                           RGB information for better compression. The default
                           value is 0.

  * `use_delta_palette<int>` (default 0):   reserved for future lossless feature
  * `use_sharp_yuv<int>` (default 0):       if needed, use sharp (and slow) RGB->YUV conversion
  * `outfile<string>` (default nil):  path to file on disk to save.

### `img:get_blob() -> return <string> binary data`

Get image data in binary string after compress process

### `img:save()`

Save image to disk base on img.compress.outfile setting. Must use before get_blob()

## Sample Code

**Nginx Configuration**
~~~~Nginx
server {
    listen 80;
    location = /favicon.ico {
        empty_gif;
    }
    location ~ /proxy(.*) {
        ## can use root or proxy_pass to get data from local or remote site
        # proxy_pass https://<origin>$1;
        root /dev/shm;
    }
    location / {
        content_by_lua_file resty-libwebp-sample.lua;
    }
}
~~~~

----
**resty-libwebp-sample.lua**
~~~~lua
local libwebp = require("resty.libwebp.webp") -- load library
-- set decompress options
libwebp.decompress.scaled_width = 1024
libwebp.decompress.colorspace = "RGBA"
-- get data direct from nginx
local res = ngx.location.capture('/proxy'..ngx.var.request_uri) -- get data from nginx location /proxy by subrequest 
local img = libwebp.load_blob(res.body) -- create object img
-- get data from disk
-- local img = libwebp.load_from_disk('/dev/shm/proxy/inputhd.webp') -- create object img
local outfile = '/dev/shm/proxy/inputhd_new.webp' -- declare outfile path
img.compress.outfile = outfile -- set outfile setting
img.compress.quality = 50 -- set quality
img.compress.method = 9 -- set speed to run
img:save() -- save file to disk
ngx.print(img:get_blob()) -- return image after compress to end user
~~~~
