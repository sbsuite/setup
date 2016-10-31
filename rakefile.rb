require 'open-uri'
require 'openssl'

#OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

task :default => :setup

REPLACEMENTS = {}
ACCOUNT_NAME = 'MichaelSevestre'
MSI = {
  'CONSOLE_APP'=> 
    {
      'project_name'=> 'consoleapp-yvmia',
      'msi_name' =>'ConsoleApp.Setup.msi',
      'artifact_path'=> 'setup/ConsoleApp.Setup/bin/Setup/',
      'branch'=>  'develop'
    },
  'MIXTEX'=>
    {
      'project_name'=> 'miktex',
      'msi_name' =>'MikTex.2.9.2.9711.msi',
      'artifact_path' => '',
      'branch' => 'master'
    }
  }   

desc "Create suite setup"
task :setup => :fetch do
#  REPLACEMENTS['PRODUCT_FULL_NAME'] =  full_name
#  REPLACEMENTS['PRODUCT_FULL_VERSION'] =  full_version  

  copy "bundle.wxs", deploy_dir
#  copy_setup_dependencies
  
  version_file = File.join(deploy_dir,'versions.txt')
  File.open(version_file, 'w') do |file| 
    REPLACEMENTS.each do |k,v|
      file.puts "#{k}: #{v}"
    end    
  end 

  #copy_to_daily_build version_file

 # Utils.replace_tokens REPLACEMENTS, File.join(deploy, "Bundle.wxs")

#  create_setup 'no', 'SBSuite-WebInstall'
 
 # create_setup 'yes', 'SBSuite-Full'
end

desc "Get a file from a remote server"
task :fetch => :clean do
  threads = []

  MSI.each_key do |msi|
    threads << Thread.new(msi) do |_msi|
      prepare_msi(_msi)
    end
  end

  threads.each { |aThread|  aThread.join }  
end

desc "cleanup files before starting compilation"
task :clean do
  FileUtils.rm_rf  deploy_dir
  FileUtils.mkdir_p deploy_dir  
end

def prepare_msi(msi)
  file = download msi

  REPLACEMENTS[msi] = File.basename(file) 
  #  copy_to_daily_build file
  #end
end

def download(msi)
  package = MSI[msi]
  file_name = package['msi_name'];
  file = File.join(deploy_dir,file_name)
  uri = "https://ci.appveyor.com/api/projects/#{ACCOUNT_NAME}/#{package['project_name']}/artifacts/#{package['artifact_path']}#{file_name}?branch=#{package['branch']}"

  puts "Download #{file_name} from #{uri}"
  open(file, 'wb') do |fo| 
    fo.print open(uri,:read_timeout => nil).read
  end
  file
end

def deploy_dir
  File.join(File.join(File.dirname(__FILE__),'deploy'))
end

