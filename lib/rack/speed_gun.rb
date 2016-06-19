require 'rack'
require 'speed_gun'
require 'speed_gun/profiler/rack_profiler'
require 'speed_gun/profiler/line_profiler'

class Rack::SpeedGun
  def initialize(app)
    @app = app
  end

  def call(env)
    return @app.call(env) if SpeedGun.config.disabled? || SpeedGun.config.skip_paths.any? { |path| path === env['PATH_INFO'] }

    SpeedGun.current_report = SpeedGun::Report.new

    SpeedGun::Profiler::RackProfiler.profile(env['PATH_INFO'], rack: rack_info(env), request: request_info(env)) do |event|
      res = SpeedGun::Profiler::LineProfiler.profile { @app.call(env) }
      res[1]['X-Speed-Gun-Report'] = SpeedGun.current_report.id
      event.payload[:response] = {
        status: res[0],
        headers: res[1]
      }
      res
    end
  ensure
    SpeedGun.current_report = nil
  end

  private

  def rack_info(env)
    {
      version: env['rack.version'],
      url_scheme: env['rack.url_scheme']
    }
  end

  def request_info(env)
    {
      method: env['REQUEST_METHOD'],
      path: env['PATH_INFO'],
      headers: request_headers(env),
      query: Rack::Utils.parse_query(env['QUERY_STRING'])
    }
  end

  def request_headers(env)
    headers = {}
    env.each_pair do |key, val|
      if key.start_with?('HTTP_')
        headers[key[5..-1].split('_').map(&:capitalize).join('-')] = val
      end
    end
    headers
  end
end
