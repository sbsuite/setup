require 'securerandom'

module Utils
  def self.replace_tokens(replacement,file) 
    content = File.read(file)

    replacement.each do |token,value|
      content.gsub!(token,value) if value
    end

    File.open(file, "w") { |f| f.write content }
  end

  def self.run_cmd(command, command_line)
    Rake::Task[:run_cmd].execute(OpenStruct.new(:command => command, :command_line => command_line))
  end

  def self.uuid
    SecureRandom.uuid
  end

  def self.join(path1, path2)
    File.join(path1,path2).tr '/', '\\'
  end
end

task :run_cmd, [:command, :command_line] do |cmd, args|
  system(args.command, *args.command_line)
end