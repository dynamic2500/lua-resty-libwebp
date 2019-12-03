local _M = {
	name = "libwebp ffi module"
}

local ffi = require('ffi')
local libwebp = require ("resty.libwebp.libwebp")

local free_t = {} --{free1, ...}
local function free()
	if not free_t then return end
	for i = #free_t, 1, -1 do
		free_t[i]()
	end
	free_t = {}
end

local function finally(func)
	table.insert(free_t, func)
end

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
-- input param is output from load()
local function compress(img)
	local return_data = ""
	if (img.compressed_data == nil) then
		local pic = ffi.new'WebPPicture'
		local wrt = ffi.new'WebPMemoryWriter[1]'
		local config = ffi.new'WebPConfig[1]'
--		libwebp.WebPConfigInitInternal(config,3,75,0x020e)
		if img.compress.speed and img.compress.speed ~= img.compress.method then
			img.compress.method = 10 - img.compress.speed
			img.compress.speed = nil
		end
		if not img.stride then
			img.stride = img.width * 4
		end
		for k,v in pairs (compress_options) do
			if not img.compress[k] then
				img.compress[k] = v
			end

		end
		for option,value in pairs (img.compress) do
			if (option ~= "outfile" and compress_options[option] ~= nil) then
				config[0][option] = value
			end

		end
		if libwebp.WebPPictureInitInternal(pic,0x020e) == 0 then
			return nil
		end

		-- Only use use_argb if we really need it, as it's slower.
		  pic.use_argb = config[0].lossless or config[0].use_sharp_yuv or config[0].preprocessing > 0
		  pic.width = img.width;
		  pic.height = img.height;
		  pic.writer = libwebp.WebPMemoryWrite;
		  pic.custom_ptr = wrt;
		local function scaleimg()
			if img.scaled_width and img.scaled_height then
				local w = ffi.new'int'
				local h = ffi.new'int'
				w = img.scaled_width
				h = img.scaled_height
				-- ngx.log(ngx.ERR, "\n\n\tAAAAA\ttoi day van ok\n\n")
				return libwebp.WebPPictureRescale(pic,w,h)
				-- ngx.log(ngx.ERR, "\n\n\tAAAAA\ttoi day het ok\n\n")
				-- ngx.log(ngx.ERR, "\n\n\tAAAAA\t"..scalestt.."\n\n")
			end
			return true
		end
		libwebp.WebPMemoryWriterInit(wrt)
		local ok = libwebp.WebPPictureImportRGBA(pic, img.raw_rgba_pixels, img.stride) and scaleimg() and libwebp.WebPEncode(config, pic)
		libwebp.WebPPictureFree(pic)
		if ok == 0 then
			libwebp.WebPMemoryWriterClear(wrt)
			-- ngx.log(ngx.ERR, "\n\n\tAAAAA\t"..pic.error_code.."\n\n")
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

local function load(data,getHeader)
	if getHeader then
		local WebPBitstreamFeatures = ffi.new("WebPBitstreamFeatures")
		local headers_status = libwebp.WebPGetFeaturesInternal(data,#data,WebPBitstreamFeatures,0x0208)
		-- ngx.log(ngx.ERR,tonumber(headers_status))
		-- ngx.log(ngx.ERR,tonumber(WebPBitstreamFeatures.width))
		return WebPBitstreamFeatures;
	end
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
	WebPDecoderConfig.output.colorspace = 1
	local ok = libwebp.WebPDecode(data, #data, WebPDecoderConfig)
	-- ngx.log(ngx.ERR,"\n\n\n??\tdebug webp decode:"..tonumber(ok).."\n\n\n")
		-- VP8_STATUS_OK = 0,
		-- VP8_STATUS_OUT_OF_MEMORY,
		-- VP8_STATUS_INVALID_PARAM,
		-- VP8_STATUS_BITSTREAM_ERROR,
		-- VP8_STATUS_UNSUPPORTED_FEATURE,
		-- VP8_STATUS_SUSPENDED,
		-- VP8_STATUS_USER_ABORT,
		-- VP8_STATUS_NOT_ENOUGH_DATA

	local img = {
		raw_rgba_pixels = WebPDecoderConfig.output.u.RGBA.rgba,
		stride = WebPDecoderConfig.output.u.RGBA.stride,
		width = WebPDecoderConfig.output.width,
		height= WebPDecoderConfig.output.height,
		compress = compress_options,
		compressed_data = nil,
	}
	
	finally(function()
		img.compressed_data = nil
		ffi.C.free(img.raw_rgba_pixels)
	end)
	
	img.free = free
	img.save = save
	img.get_blob = get_blob
	return img
end

local function load_blob(blob,getHeader)
	getHeader = getHeader or nil
	return load(blob,getHeader)
end

local function load_from_disk(infile)
	local f = io.open(infile, "rb")
	local blob, err = f:read("*all")
	f:close()
	if (blob) then
		return load(blob,nill)
	else
		return nil
	end
end

_M.decode = decode_config
_M.load_blob = load_blob
_M.compress = compress
_M.load_from_disk = load_from_disk
return _M
