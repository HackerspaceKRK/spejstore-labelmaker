require 'rubygems'
require 'sinatra'
require 'prawn'
require 'prawn/measurements'
require 'prawn/qrcode'
require 'json'
require 'shellwords'
require 'uri'
require 'net/http'

include Prawn::Measurements

CODE_PREFIX = ENV.fetch('LABELMAKER_CODE_PREFIX', 'https://inventory.hackerspace.pl/')

# NOTE:
# DYMO_LABEL_SIZE = [89, 36]
# ZEBRA_LABEL_SIZE = [100, 60]
LABEL_SIZE = JSON.parse(ENV.fetch('LABELMAKER_LABEL_SIZE', '[89, 36]'))

# NOTE: You can use only one of these: local printer, IPP printer, or printservant
LOCAL_PRINTER_NAME = ENV.fetch('LABELMAKER_LOCAL_PRINTER_NAME', '')
IPP_PRINTER_URL = ENV.fetch('LABELMAKER_IPP_PRINTER_URL', '')
WEBHOOK = ENV.fetch('LABELMAKER_WEBHOOK', '') # printservant-compatible print url

if LOCAL_PRINTER_NAME.empty? and IPP_PRINTER_URL.empty? and WEBHOOK.empty?
  raise "No printer configured"
end

def render_label()
  short_id = params[:id]
  name = params[:name]
  owner = params[:owner]

  if short_id.nil? or name.nil?
    status 400
    return "Missing required parameters ?id= and ?name="
  end

  pdf = Prawn::Document.new(page_size: LABEL_SIZE.map { |x| mm2pt(x) },
                            margin: [2, 2, 2, 6].map { |x| mm2pt(x) }) do
    font_families.update("DejaVuSans" => {
      normal: "fonts/DejaVuSans.ttf",
      italic: "fonts/DejaVuSans-Oblique.ttf",
      bold: "fonts/DejaVuSans-Bold.ttf",
      bold_italic: "fonts/DejaVuSans-BoldOblique.ttf"
    })

    font 'DejaVuSans'

    # Width of right side
    qr_size = [bounds.height / 2, 27].max

    # Right side
    bounding_box([bounds.right - qr_size, bounds.top], width: qr_size) do
      print_qr_code CODE_PREFIX + short_id, stroke: false,
        foreground_color: '000000',
        extent: bounds.width, margin: 0, pos: bounds.top_left

      owner_text = owner && !owner.empty? ? "owner: #{owner}\n\n" : ""
      metadata_text = owner_text # todo: creation date?

      text_box metadata_text,
        at: [bounds.right - qr_size, -7], size: 8, align: :right, overflow: :shrink_to_fit
    end

    # Left side
    bounding_box(bounds.top_left, width: bounds.width - qr_size) do
      text_box name,
        size: 40, align: :center, valign: :center, width: bounds.width-10,
        inline_format: true, overflow: :shrink_to_fit, disable_wrap_by_char: true
    end
  end

  pdf.render
end

set :bind, '0.0.0.0'

get '/api/2/health' do
  "I'm cool"
end

get '/api/2/preview.pdf' do
  headers["Content-Type"] = "application/pdf; charset=utf8"
  render_label
end

post '/api/2/print' do
  if not WEBHOOK.empty?
    uri = URI(WEBHOOK)
    reponse = Net::HTTP.post(uri, render_label)
    puts reponse.body
    return
  end

  temp = Tempfile.new('labelmaker')
  temp.write(render_label)
  temp.close

  if not LOCAL_PRINTER_NAME.empty?
    system("lpr -P #{LOCAL_PRINTER_NAME.shellescape} #{temp.path.shellescape}", exception: true)
  elsif not IPP_PRINTER_URL.empty?
    system("ipptool -v -tf #{temp.path.shellescape} -d filetype=application/octet-stream -I #{IPP_PRINTER_URL.shellescape} ipptool-print-job.test", exception: true)
  end
end
