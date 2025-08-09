#!/usr/bin/env ruby

require 'fileutils'

require 'liquid'
require 'zip'

RSVG_CONVERT = ENV.fetch 'RSVG_CONVERT', 'rsvg-convert'
OUTPUT_DIR = ENV.fetch 'OUTPUT_DIR', 'build'
OUTPUT_FILE = ENV['OUTPUT_FILE']
SOURCE_DIR = File.expand_path '../src', __FILE__

@templates = {}
@cache = {}
@files = []

def main
	FileUtils.mkdir_p OUTPUT_DIR
	build_skin_ini
	build_main_hud_components
	build_cursor
	build_combo_burst
	build_judgement
	build_note
	build_score_and_combo
	build_health_display
	package if OUTPUT_FILE
end

def cp filename
	$stderr.puts "Building #{filename}"
	out = File.join OUTPUT_DIR, filename
	FileUtils.cp File.join(SOURCE_DIR, filename), out
	@files.push out
end

def dp src, dst
	FileUtils.cp src, dst
	@files.push dst
end

def rsvg_convert input, filename, **options
	IO.popen [RSVG_CONVERT, ?-] + options.flat_map { |k, v| ["--#{k.to_s.tr ?_, ?-}", v.to_s] }, 'r+' do |io|
		io.write input
		io.close_write
		File.open(filename, 'wb') { IO.copy_stream io, it }
	end
	@files.push filename
end

def sd filename
	File.join OUTPUT_DIR, filename + '.png'
end

def hd filename
	File.join OUTPUT_DIR, filename + '@2x.png'
end

def m source, target = source, **opts
	$stderr.puts "Building #{target}"
	cache_key = [source, opts]
	if cached = @cache[cache_key]
		dp sd(cached), sd(target)
		dp hd(cached), hd(target) unless source == 'transparent'
		return
	end
	template = @templates[source] ||= Liquid::Template.parse(File.read File.join SOURCE_DIR, source + '.svg')
	svg_contents = template.render opts.transform_keys &:to_s
	rsvg_convert svg_contents, sd(target)
	rsvg_convert svg_contents, hd(target), zoom: 2 unless source == 'transparent'
	@cache[cache_key] = target
end

def build_cursor
	m 'transparent', 'cursortrail'
	m 'cursor'
end

def build_combo_burst
	m 'transparent', 'Star2'
	m 'transparent', 'comboburst'
end

def build_judgement
	m 'judgement', 'hit0', color: '#e91212'
	m 'judgement', 'hit50', color: '#ffdd87'
	m 'judgement', 'hit100', color: '#96eb6c'
	m 'judgement', 'hit100k', color: '#96eb6c'
	m 'transparent', 'hit300-0'
	m 'transparent', 'hit300g-0'
	m 'transparent', 'hit300k-0'

	m 'slider-judgement', 'slidertickmiss', color: '#ff7777'
	m 'slider-judgement', 'sliderendmiss', color: '#e282fe'

	m 'transparent', 'lighting'
end

def build_note
	10.times { |i| m 'hitcircle', "default-#{i}", has_dot: i == 1 }

	m 'transparent', 'hitcircleoverlay', width: 128
	m 'transparent', 'hitcircle', width: 128
	m 'approachcircle'

	m 'transparent', 'sliderendcircle', width: 128
	m 'sliderb'
	m 'sliderfollowcircle'
	m 'sliderscorepoint'
	m 'reversearrow'

	10.times { |i| m (3..5).include?(i) ? 'followpoint' : 'transparent', "followpoint-#{i}" }

	m 'spinner-spin'
	m 'spinner-bottom'
	m 'spinner-middle'
	m 'spinner-approachcircle'
	m 'transparent', 'spinner-top'
	m 'transparent', 'spinner-middle2'
	m 'transparent', 'spinner-glow'
	m 'transparent', 'spinner-clear'
	m 'transparent', 'spinner-rpm'
end

def build_score_and_combo
	10.times do |i|
		m 'score', "score-#{i}", text: i.to_s, is_combo: false
		m 'score', "combo-#{i}", text: i.to_s, is_combo: true
	end
	m 'score', 'score-dot', text: ?., is_combo: false
	m 'score', 'score-comma', text: ?., is_combo: false
	m 'transparent', 'score-x', width: 16, height: 20
	m 'transparent', 'score-percent', width: 3, height: 1
end

def build_health_display
	m 'scorebar-colour'
	m 'transparent', 'scorebar-marker'
	m 'transparent', 'scorebar-bg'
end

def build_skin_ini
	cp 'skin.ini'
end

def build_main_hud_components
	cp 'MainHUDComponents.json'
end

def package
	FileUtils.rm OUTPUT_FILE if File.exist? OUTPUT_FILE
	FileUtils.mkdir_p File.dirname OUTPUT_FILE
	Zip::File.open OUTPUT_FILE, create: true do |zip|
		@files.each { |file| zip.add File.basename(file), file }
		zip.each { it.time = Time.at 0 }
	end
end

main
