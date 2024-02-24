class Package < Skippy::Command

  desc 'build', 'Package up the extension into a RBZ.'
  def build
    require 'zip'

    project = Skippy::Project.current_or_fail
    say "Extension source path: #{project.extension_source}", :blue

    root_file = project.extension_source.join("#{project.basename}.rb")

    content = root_file.read
    version = content[/PLUGIN_VERSION\s*=\s*'([0-9.]+)'/, 1]
    say "Extension version: #{version}", :blue

    archive_path = project.path('archive')
    archive_path.mkpath

    build_date = Time.now.strftime('%Y-%m-%d')
    rbz_filename = "#{project.basename}-#{version}_#{build_date}.rbz"
    rbz_path = archive_path.join(rbz_filename)

    relative_rb_path = rbz_path.relative_path_from(project.path)

    if rbz_path.exist?
      if yes? "Archive #{relative_rb_path} already exist. Overwrite?"
        rbz_path.delete
      else
        exit
      end
    end

    build_base_path = project.extension_source.to_s
    build_files_pattern = project.extension_source.join('**', '*')
    Zip::File.open(rbz_path.to_s, Zip::File::CREATE) do |zip_file|
      build_files = Dir.glob(build_files_pattern)
      build_files.each { |file_item|
        next if File.directory?(file_item)

        pathname = Pathname.new(file_item)
        relative_name = pathname.relative_path_from(build_base_path)
        say "Archiving: #{relative_name}"
        zip_file.add(relative_name, file_item)
      }
    end
    say "Created #{relative_rb_path}", :yellow
  end
  default_command(:build)

end
