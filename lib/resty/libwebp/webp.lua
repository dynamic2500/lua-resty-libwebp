local _M = {
	name = "libwebp ffi module"
}

local ffi = require('ffi')
local libwebp = require ("resty.libwebp.libwebp")

local decode_config = {
	bypass_filtering = true,
	no_fancy_upsampling = true,
	scaled_width = nil,
	scaled_height = nil,
	use_scaling = false,
	use_threads = true,
	dithering_strength = 0,
	alpha_dithering_strength = 0,
--	use_cropping = false,
--	crop_left = nil,
--	crop_top = nil,
--	crop_width = nil,
--	crop_height = nil,
}

-- input param is output from load()
local function compress(img)
	local return_data = ""
	if (img.compressed_data == nil) then
		local pic = ffi.new'WebPPicture[1]'
		local wrt = ffi.new'WebPMemoryWriter[1]'
		local config = ffi.new'WebPConfig[1]'
--		libwebp.WebPConfigInitInternal(config,3,75,0x020e)
		for option,value in pairs (img.compress) do
			if (option ~= "outfile") then
				config[0][option] = value
			end

		end
		if libwebp.WebPPictureInitInternal(pic,0x020e) == 0 then
			return nil
		end

		-- Only use use_argb if we really need it, as it's slower.
		  pic[0].use_argb = config[0].lossless or config[0].use_sharp_yuv or config[0].preprocessing > 0
		  pic[0].width = img.width;
		  pic[0].height = img.height;
		  pic[0].writer = libwebp.WebPMemoryWrite;
		  pic[0].custom_ptr = wrt;

		libwebp.WebPMemoryWriterInit(wrt)
		local ok = libwebp.WebPPictureImportRGB(pic, img.raw_rgba_pixels, img.stride) and libwebp.WebPEncode(config, pic)
		libwebp.WebPPictureFree(pic)
		if ok == 0 then
			libwebp.WebPMemoryWriterClear(wrt)
			return nil
			--[[ ERROR code For Debug
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
			VP8_ENC_ERROR_LAST                      // list terminator. always last.--]]
		end
		return_data = ffi.string(wrt[0].mem,tonumber(wrt[0].size))
		local last_result = wrt[0].mem
		libwebp.WebPFree(last_result)
		img.compressed_data = return_data
	else
		return_data = img.compressed_data
	end

	if (img["compress"]["outfile"]) then
		local fout = io.open(img["compress"]["outfile"],"w")
		if (fout) then
			fout:write(return_data)
			fout:close()
			return 0
		else
			return nil
		end
	end
	return return_data
end

local function save(img)
	if (img["compress"]["outfile"]) then
		compress(img)
	else
		return nil
	end
end

local function get_blob(img)
	img["compress"]["outfile"] = nil
	return compress(img)
end

local function load(data)
	local WebPDecoderConfig = ffi.new("WebPDecoderConfig")
	libwebp.WebPInitDecoderConfigInternal(WebPDecoderConfig,0x0208)
	for option, value in pairs (decode_config) do
		if (value) then
			WebPDecoderConfig.options[option] = value
			if (option == "scaled_width" or option == "scaled_height") then
				WebPDecoderConfig.options.use_scaling = true
			end
		end
	end
	libwebp.WebPDecode(data, #data, WebPDecoderConfig)
	local compress_options = {
		quality = 75,
		target_size = 0,
		target_PSNR = 0,
		method = 4,
		sns_strength = 50,
		filter_strength = 60,
		filter_sharpness = 0,
		filter_type = 1,
		partitions = 0,
		segments = 4,
		pass = 1,
		show_compressed = 0,
		preprocessing = 0,
		autofilter = 0,
		partition_limit = 0,
		alpha_compression = 1,
		alpha_filtering = 1,
		alpha_quality = 100,
		lossless = 0,
		exact = 0,
		image_hint = 0,
		emulate_jpeg_size = 0,
		thread_level = 1,
		low_memory = 0,
		near_lossless = 100,
		use_delta_palette = 0,
		use_sharp_yuv = 0,
		outfile = nil
	}
	local img = {
		raw_rgba_pixels = WebPDecoderConfig.output.u.RGBA.rgba,
		stride = WebPDecoderConfig.output.u.RGBA.stride,
		width = WebPDecoderConfig.output.width,
		height= WebPDecoderConfig.output.height,
		compress = compress_options,
		compressed_data = nil,
	}
	img.save = function () return save(img) end
	img.get_blob = function() return get_blob(img) end
	return img
end

local function load_blob(blob)
	return load(blob)
end

local function load_from_disk(infile)
	local f = io.open(infile, "rb")
	local blob, err = f:read("*all")
	f:close()
	if (blob) then
		return load(blob)
	else
		return nil
	end
end

_M.decode = decode_config
_M.load_blob = load_blob
_M.load_from_disk = load_from_disk
return _M
