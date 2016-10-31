require 'open-uri'
require 'openssl'
require_relative 'utils'

OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

task :default => :setup

VERSION = ENV['APPVEYOR_BUILD_VERSION']
PRODUCT_NAME = 'ConsoleAppBundle'
REPLACEMENTS = {}
ACCOUNT_NAME = 'MichaelSevestre'

MSI = {
  'CONSOLE_APP'=> 
    {
      'project_name'=> 'consoleapp-yvmia',
      'artifact_name' =>'ConsoleApp.Setup.msi',
      'artifact_path'=> 'setup/ConsoleApp.Setup/bin/Setup/',
      'branch'=>  'develop'
    },
  'MIKTEX'=>
    {
      'project_name'=> 'miktex',
      'artifact_name' =>'MikTex.2.9.2.9711.msi',
      'artifact_path' => '',
      'branch' => 'master'
    },
  'DOTNET'=>
    {
      'artifact_name' => 'dotnetfx45_full_x86_x64.exe',
      'uri' => 'http://go.microsoft.com/fwlink/?LinkId=225702'
    }
  }   

desc "Create suite setup"
task :setup => :fetch do
  REPLACEMENTS['PRODUCT_FULL_NAME'] =  PRODUCT_NAME
  REPLACEMENTS['PRODUCT_FULL_VERSION'] =  VERSION
  
  copy "bundle.wxs", deploy_dir
#  copy_setup_dependencies
  
  version_file = File.join(deploy_dir,'versions.txt')
  File.open(version_file, 'w') do |file| 
    REPLACEMENTS.each do |k,v|
      file.puts "#{k}: #{v}"
    end    
  end 

  #copy_to_daily_build version_file

 Utils.replace_tokens REPLACEMENTS, File.join(deploy_dir, "bundle.wxs")

#  create_setup 'no', 'SBSuite-WebInstall'
 
  create_setup 'yes', 'Setup-Full'
end

def run_candle(compressed)
  command_line = %W[#{deploy_dir}/bundle.wxs -dCompressed=#{compressed} -ext WixUtilExtension -ext WixNetFxExtension -ext WixBalExtension -o #{deploy_dir}/]
  Utils.run_cmd(candle, command_line)
end

desc "Runs the light command that actually creates the msi package"
def run_light(exe)
  command_line = %W[#{deploy_dir}/Bundle.wixobj -o #{exe} -nologo -ext WixUIExtension -ext WixNetFxExtension -ext WixBalExtension -spdb -b #{deploy_dir}/ -cultures:en-us]
  Utils.run_cmd(light, command_line)
end

def create_setup(compressed, name)
  exe = "#{output_dir}/#{name}.#{VERSION}.exe"
  run_candle compressed
  run_light exe
end

desc "Get a file from a remote server"
task :fetch => :clean do
  threads = []

  MSI.each_key do |msi|
    threads << Thread.new(msi) do |_msi|
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

  REPLACEMENTS[msi] = package['artifact_name'] 
  #  copy_to_daily_build file
end

def download(package)
  file_name = package['artifact_name'];
  file = File.join(deploy_dir,file_name)
  uri = package['uri'];
  uri = "https://ci.appveyor.com/api/projects/#{ACCOUNT_NAME}/#{package['project_name']}/artifacts/#{package['artifact_path']}#{file_name}?branch=#{package['branch']}" unless uri

  puts "Download #{file_name} from #{uri}"
  open(file, 'wb') do |fo| 
    fo.print open(uri,:read_timeout => nil).read
  end
  file
end

def deploy_dir
  File.join(File.join(File.dirname(__FILE__),'deploy'))
end

def output_dir
  File.join(File.join(File.dirname(__FILE__),'output'))
end

def candle
  File.join(wix_bin,'candle.exe')
end 

def light
  File.join(wix_bin,'light.exe')
end

def wix_bin
  'C:\Program Files (x86)\WiX Toolset v3.10\bin'
end


