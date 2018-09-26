def versionFile(name)
  version_file_location = ENV["VERSION_FILE_LOCATION"] || 'version.json'
  JSON.parse(File.read(version_file_location))[name] if File.file?(version_file_location)
end

def get_var(name)
  value = ENV[name]
  raise "\e[1;31m[ERROR]\e[0m  Environment #{name} not specified!" if value.to_s.strip.empty?
  value
end

class Docker
  def self.login
    token = ENV["TOKEN"]
    if token
      FileUtils.mkdir_p "#{Dir.home}/.docker"
      File.open("#{Dir.home}/.docker/config.json", "w") do |f|
        f.write({:auths => {"https://index.docker.io/v1/" => {:auth => token}}}.to_json)
      end
    else
      puts "\e[1;33m[WARN]\e[0m Skipping docker login as environment variable TOKEN is not specified."
    end
  end
end
