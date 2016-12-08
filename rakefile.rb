require 'open-uri'
require 'openssl'

OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

task :default => [:load_dependencies, :setup]

VERSION = '0.4.2'
FULL_VERSION = ENV['APPVEYOR_BUILD_VERSION'] || '0.4.2.0'
PRODUCT_NAME = 'ConsoleAppBundle'
GITHUB_NAME = 'msevestre'

#Account name on AppVeyor
ACCOUNT_NAME = 'MichaelSevestre'

#Branch used to retrieve custom msi packages
BRANCH_NAME = 'develop'

REPLACEMENTS = {}

def create_package(appveyor_project_name, artifact_name, git_repository, version: VERSION, branch:BRANCH_NAME)
  compressed = artifact_name.include? '.zip'
  return {
    appveyor_project_name: appveyor_project_name,
    artifact_name: artifact_name,
    branch: branch,
    compressed: compressed,
    git_repository: git_repository,
    version: version
  } 
end

MSI = {
  'CONSOLE_APP'=>  create_package('consoleapp-yvmia', 'setup.zip', 'consoleapp'),
  'MIKTEX'=> create_package('miktex', 'MikTex.2.9.2.9711.msi','miktex', version: '2.9.2', branch: 'master'),
  'DOTNET'=>
    {
      artifact_name: 'dotnetfx45_full_x86_x64.exe',
      uri: 'http://go.microsoft.com/fwlink/?LinkId=225702'
    }
  }   

desc "Ensure that all required files are loaded"
task :load_dependencies do
  packages_rb_files = File.join('.','packages',  '**', '*.rb')
  Dir.glob(packages_rb_files).each{|x|  require_relative x}
end

desc "Create suite setup"
task :setup => :fetch do
  REPLACEMENTS['PRODUCT_FULL_NAME'] =  PRODUCT_NAME
  REPLACEMENTS['PRODUCT_FULL_VERSION'] =  FULL_VERSION
  
  copy "bundle.wxs", deploy_dir
  
  version_file = File.join(output_dir,'versions.txt')
  File.open(version_file, 'w') do |file| 
    REPLACEMENTS.each do |k,v|
      file.puts "#{k}: #{v}"
    end    
  end 

 Utils.replace_tokens REPLACEMENTS, File.join(deploy_dir, "bundle.wxs")

#  create_setup 'no', 'SBSuite-WebInstall'
 
  create_setup 'yes', 'Setup-Full'
end

def run_candle(compressed)
  command_line = %W[#{deploy_dir}/bundle.wxs -dCompressed=#{compressed} -ext WixUtilExtension -ext WixNetFxExtension -ext WixBalExtension -o #{deploy_dir}/]
  Utils.run_cmd(Wix.candle, command_line)
end

desc "Runs the light command that actually creates the msi package"
def run_light(exe)
  command_line = %W[#{deploy_dir}/Bundle.wixobj -o #{exe} -nologo -ext WixUIExtension -ext WixNetFxExtension -ext WixBalExtension -spdb -b #{deploy_dir}/ -cultures:en-us]
  Utils.run_cmd(Wix.light, command_line)
end

def create_setup(compressed, name)
  exe = "#{output_dir}/#{name}.#{FULL_VERSION}.exe"
  run_candle compressed
  run_light exe
end

desc "Get a file from a remote server"
task :fetch => :clean do
  threads = MSI.each_key.collect do |msi|
    Thread.new(msi) do |_msi|
      prepare_msi(_msi)
    end
  end

  threads.map(&:join)
end

desc "cleanup files before starting compilation"
task :clean do
  FileUtils.rm_rf  deploy_dir
  FileUtils.mkdir_p deploy_dir  
  FileUtils.mkdir_p output_dir  
end

def prepare_msi(msi)
  package =  MSI[msi]
  file = download package
  puts file
  package_name = retrieve_package_name(file, package) 
  download_path = "https://github.com/#{GITHUB_NAME}/#{package[:git_repository]}/releases/download/v#{package[:version]}/#{package_name}"
  REPLACEMENTS["#{msi}_DOWNLOAD_PATH"] = download_path
  REPLACEMENTS[msi] = package_name
end

def download(package)
  file_name = package[:artifact_name]
  uri = package[:uri];
  uri = "https://ci.appveyor.com/api/projects/#{ACCOUNT_NAME}/#{package[:appveyor_project_name]}/artifacts/#{package[:artifact_path]}#{file_name}?branch=#{package[:branch]}" unless uri
  download_file file_name, uri
end

def download_file(file_name, uri)
  file = File.join(deploy_dir, file_name)
  puts "Downloading #{file_name} from #{uri}"
  open(file, 'wb') do |fo| 
    fo.print open(uri,:read_timeout => nil).read
  end
  file
end

def retrieve_package_name(package_full_path, package)
  compressed = package[:compressed] || false
  artifact_name = package[:artifact_name];
  #pointing to real package already return 
  return artifact_name unless compressed

  unzip_dir = unzip(package_full_path)
  copy_msi_to_deploy unzip_dir  
end

#copy all msi packages defined under dir and return the name of the packages found (should only be one)
def copy_msi_to_deploy(dir)
  artifact_name = ''
  Dir.glob(File.join(dir, '*.msi')) do |x|
    copy x, deploy_dir
    artifact_name = File.basename(x)
  end 
  artifact_name
end

def unzip(package_full_path)
  zip_name = File.basename(package_full_path, '.zip')
  unzip_dir = File.join(deploy_dir, zip_name)
  command_line = %W[e #{package_full_path} -o#{unzip_dir}]
  Utils.run_cmd('7z', command_line)
  unzip_dir
end

def deploy_dir
  File.join(current_dir,'deploy')
end

def output_dir
  File.join(current_dir,'output')
end

def current_dir
  File.dirname(__FILE__)
end

