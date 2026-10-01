# Remove the background of one image — Ruby 2.7+, standard library only.
#
#   PIXMILLER_API_KEY=... ruby remove_background.rb product.jpg [out.png]
#
# Env: PIXMILLER_API_BASE (default https://api.pixmiller.com), PIXMILLER_SIZE (default auto).
require "json"
require "net/http"
require "uri"

API_BASE = ENV.fetch("PIXMILLER_API_BASE", "https://api.pixmiller.com") # was https://api.remove.bg
API_KEY = ENV["PIXMILLER_API_KEY"]
SIZE = ENV.fetch("PIXMILLER_SIZE", "auto") # preview/small/regular = free, watermarked

def remove_background(path, max_retries: 3)
  uri = URI("#{API_BASE}/v1.0/removebg")
  (0..max_retries).each do |attempt|
    response = File.open(path, "rb") do |image|
      request = Net::HTTP::Post.new(uri)
      request["X-Api-Key"] = API_KEY
      request.set_form([["image_file", image], ["size", SIZE]], "multipart/form-data")
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", read_timeout: 120) do |http|
        http.request(request)
      end
    end
    if response.code == "429" && attempt < max_retries
      wait = Integer(response["Retry-After"] || 5, exception: false) || 5
      warn "rate limited, retrying in #{wait}s"
      sleep wait
      next
    end
    return response
  end
end

abort "Set PIXMILLER_API_KEY (https://pixmiller.com/en/users/~api/)" if API_KEY.to_s.empty?
abort "usage: ruby remove_background.rb input-image [output.png]" if ARGV.empty?
output = ARGV[1] || "out.png"

response = remove_background(ARGV[0])
unless response.code == "200"
  # Same envelope as remove.bg: {"errors":[{"code":"…","title":"…"}]}
  error = (JSON.parse(response.body)["errors"] || [{}]).first rescue {}
  warn "error: HTTP #{response.code} #{error['code']}: #{error['title'] || response.body}"
  exit 1
end

File.binwrite(output, response.body)
puts "saved #{output} · #{response['X-Width']}x#{response['X-Height']} px · " \
     "credits charged: #{response['X-Credits-Charged']} · type: #{response['X-Type']}"
