require 'rubygems'
require 'sinatra'
require 'rqrcode'
require 'prawn'
require 'prawn/measurements'
require 'prawn/qrcode'
require 'prawn-svg'
require 'color'
require 'excon'
require 'rmagick'
require 'json'
require 'zlib'
require 'shellwords'

include Prawn::Measurements

BACKEND_URL = ENV.fetch('LABELMAKER_BACKEND_URL', 'https://inventory.hackerspace.pl/api/1/')
CODE_PREFIX = ENV.fetch('LABELMAKER_CODE_PREFIX', 'https://inventory.hackerspace.pl/')

# NOTE:
# DYMO_LABEL_SIZE = [89, 36]
# ZEBRA_LABEL_SIZE = [100, 60]
LABEL_SIZE = JSON.parse(ENV.fetch('LABELMAKER_LABEL_SIZE', '[89, 36]'))

# NOTE: You can use either local printer or IPP printer, but not both
LOCAL_PRINTER_NAME = ENV.fetch('LABELMAKER_LOCAL_PRINTER_NAME', 'DYMO_LabelWriter_450')
IPP_PRINTER_URL = ENV.fetch('LABELMAKER_IPP_PRINTER_URL', '')
DEBUG_JSON = ENV["LABELMAKER_DEBUG_JSON"]

def api(uri)
  if DEBUG_JSON
    JSON.parse(DEBUG_JSON)
  else
    JSON.parse(Excon.get(BACKEND_URL + uri + "/"))
  end
end

def render_label(item_or_label_id, size: LABEL_SIZE)
  item = api("items/#{item_or_label_id}")

  pdf = Prawn::Document.new(page_size: size.map { |x| mm2pt(x) },
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
      print_qr_code CODE_PREFIX + item['short_id'], stroke: false,
        foreground_color: '000000',
        extent: bounds.width, margin: 0, pos: bounds.top_left

      owner_text = item["owner"] ? "owner: #{item['owner']}\n\n" : ""
      metadata_text = owner_text # todo: creation date?

      text_box metadata_text,
        at: [bounds.right - qr_size, -7], size: 8, align: :right, overflow: :shrink_to_fit
    end

    # Left side
    bounding_box(bounds.top_left, width: bounds.width - qr_size) do
      text_box item['name'],
        size: 40, align: :center, valign: :center, width: bounds.width-10,
        inline_format: true, overflow: :shrink_to_fit, disable_wrap_by_char: true
    end
  end

  pdf.render
end

set :bind, '0.0.0.0'

get '/api/1/preview/:id.pdf' do
  headers["Content-Type"] = "application/pdf; charset=utf8"
  render_label params["id"]
end

get '/api/1/preview/:id.png' do
  headers["Content-Type"] = "image/png"
  img = Magick::ImageList.new()
  img = img.from_blob(render_label(params["id"])){ self.density = 200 }.first
  img.format = 'png'
  img.background_color = 'white'
  img.to_blob
end

post '/api/1/print/:id' do
  temp = Tempfile.new('labelmaker')
  temp.write(render_label(params["id"]))
  temp.close

  if not LOCAL_PRINTER_NAME.empty?
    system("lpr -P #{LOCAL_PRINTER_NAME.shellescape} #{temp.path.shellescape}", exception: true)
  elsif not IPP_PRINTER_URL.empty?
    system("ipptool -v -tf #{temp.path.shellescape} -d filetype=application/octet-stream -I #{IPP_PRINTER_URL.shellescape} ipptool-print-job.test", exception: true)
  else
    status 404
    return "No printer configured"
  end
end
