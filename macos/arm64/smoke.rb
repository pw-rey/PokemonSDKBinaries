abort 'Unexpected Ruby version' unless RUBY_VERSION == '3.4.10'
abort 'Expected native ARM Ruby' unless RUBY_PLATFORM.start_with?('arm64-darwin')
$stdout.sync = true
%w[openssl psych zlib fiddle/import socket json bigdecimal date stringio strscan
   LiteRGSS SFMLAudio RubyFmod SFEMovie].each do |name|
  puts "Loading #{name}"
  require name
end
abort 'OpenSSL digest failed' unless OpenSSL::Digest::SHA256.hexdigest('PSDK').size == 64
abort 'YAML failed' unless Psych.safe_load('test: 42')['test'] == 42
abort 'zlib failed' unless Zlib.inflate(Zlib.deflate('PSDK')) == 'PSDK'
abort 'Unexpected FMOD API version' unless FMOD::VERSION == 0x00020220
abort 'Missing movie binding' unless defined?(SFE::Movie)
abort 'Missing graphics binding' unless defined?(LiteRGSS::Bitmap)
abort 'Missing audio binding' unless defined?(SFMLAudio::Music)
runtime_lib = File.expand_path('lib', Dir.pwd)
module AVCodec
  extend Fiddle::Importer
  dlload File.expand_path('lib/libavcodec.60.dylib', Dir.pwd)
  extern 'void *avcodec_find_decoder_by_name(const char *)'
end
%w[png mov_text h264 vorbis aac].each do |decoder|
  abort "Missing decoder: #{decoder}" if AVCodec.avcodec_find_decoder_by_name(decoder).to_i.zero?
end
Fiddle.dlopen(File.join(runtime_lib, 'libsfeMovie.dylib'))
# Exercise native objects as well as dlopen. A generated PCM fixture needs no
# external media download, audio device, encoder or copyrighted sample file.
samples = "\0".b * 8820
wave = 'RIFF'.b + [36 + samples.bytesize].pack('V') + 'WAVEfmt '.b +
       [16, 1, 1, 44_100, 88_200, 2, 16].pack('VvvVVvv') +
       'data'.b + [samples.bytesize].pack('V') + samples
File.binwrite('smoke.wav', wave)
FMOD::System.setOutput(FMOD::OUTPUTTYPE::NOSOUND)
FMOD::System.init(8, FMOD::INIT::NORMAL)
abort 'FMOD runtime version mismatch' unless FMOD::System.getVersion == 0x00020220
sound = FMOD::System.createSound('smoke.wav', FMOD::MODE::FMOD_2D, nil)
abort 'FMOD PCM decode failed' unless sound.getLength(FMOD::TIMEUNIT::MS) == 100
sound.release
FMOD::System.close
FMOD::System.release
music = SFMLAudio::Music.new
abort 'SFML audio decode failed' unless music.open_from_file('smoke.wav')
abort 'SFML audio duration failed' unless (music.get_duration - 0.1).abs < 0.001
bitmap = LiteRGSS::Bitmap.new(2, 2)
abort 'OpenGL texture creation failed' unless bitmap.width == 2 && bitmap.height == 2
bitmap.dispose
movie = SFE::Movie.new
abort 'sfeMovie demux failed' unless movie.open_from_file('smoke.wav')
abort 'sfeMovie duration failed' unless (movie.get_duration - 0.1).abs < 0.001
movie.play
movie.update
movie.stop
load File.expand_path('../../tests/sfemovie-texture.rb', __dir__)
root = Dir.pwd + '/'
foreign = $LOADED_FEATURES.select { |p| p.start_with?('/') && !p.start_with?(root) }
abort "Loaded host Ruby files: #{foreign}" unless foreign.empty?
puts "Ruby #{RUBY_VERSION}: relocated libraries, audio decoding, OpenGL texture and movie smoke tests passed."
File.write('smoke-passed', "Ruby #{RUBY_VERSION}\n")
