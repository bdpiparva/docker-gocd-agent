# Copyright 2018 ThoughtWorks, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'erb'
require 'open-uri'
require 'json'

gocd_full_version = versionFile('go_full_version') || get_var('GOCD_FULL_VERSION')
gocd_version = versionFile('go_version') || get_var('GOCD_VERSION')
gocd_git_sha = versionFile('git_sha') || get_var('GOCD_GIT_SHA')
remove_image_post_push = ENV['CLEAN_IMAGES'] || true
download_url = ENV['GOCD_AGENT_DOWNLOAD_URL'] || "https://download.gocd.org/experimental/binaries/#{gocd_full_version}/generic/go-agent-#{gocd_full_version}.zip"

maybe_credentials = "#{ENV['GIT_USER']}:#{ENV['GIT_PASSWORD']}@" if ENV['GIT_USER'] && ENV['GIT_PASSWORD']

windows_docker_images = [
    {
        base_image_name: 'microsoft/windowsservercore',
        version: '1803',
        release_name: '1803'
    }
]

windows_docker_images.each do |image|
  base_image_name = image[:base_image_name]
  version = image[:version]
  release_name = image[:release_name]
  image_tag = "v#{gocd_version}"

  repo_name = "docker-#{base_image_name.gsub('/', '-')}-#{version}"
  dir_name = "build/#{repo_name}"
  repo_url = "https://#{maybe_credentials}github.com/#{ENV['REPO_OWNER'] || 'gocd'}/#{repo_name}"

  namespace repo_name do
    task :clean do
      rm_rf dir_name
    end

    task :init do
      sh(%(git clone --quiet "#{repo_url}" #{dir_name}))
    end

    task :create_entrypoint_script do
      docker_template = File.read('docker-entrypoint.sh.erb')
      docker_renderer = ERB.new(docker_template, nil, '-')
      File.open("#{dir_name}/docker-entrypoint.sh", 'w') do |f|
        f.puts(docker_renderer.result(binding))
      end
      sh("chmod +x #{dir_name}/docker-entrypoint.sh")
    end

    task :create_dockerfile => :create_entrypoint_script do
      create_dockerfile(dir_name, 'Dockerfile.windows.erb')
      create_readme(dir_name, 'README.windows.erb')
      copy_license_and_logback_config(dir_name)
    end
  end
end

def create_dockerfile(dir_name, docker_file_template)
  docker_renderer = ERB.new(File.read("#{ROOT_DIR}/#{docker_file_template}"), nil, '-')
  File.open("#{dir_name}/Dockerfile", 'w') do |f|
    f.puts(docker_renderer.result(binding))
  end
end

def create_readme(dir_name, readme_template)
  readme_renderer = ERB.new(File.read("#{ROOT_DIR}/#{readme_template}"), nil, '-')
  File.open("#{dir_name}/README.md", 'w') do |f|
    f.puts(readme_renderer.result(binding))
  end
end

def copy_license_and_logback_config(dir_name)
  cp "#{ROOT_DIR}/LICENSE-2.0.txt", "#{dir_name}/LICENSE-2.0.txt"
  Dir['*-logback-include.xml'].each do |f|
    cp f, "#{dir_name}"
  end
end
