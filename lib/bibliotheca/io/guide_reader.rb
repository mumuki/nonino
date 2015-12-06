module Bibliotheca::IO
  class GuideReader
    include Bibliotheca::IO::WithFileReading

    attr_reader :dir, :log

    def initialize(dir, repo, log)
      @dir = File.expand_path(dir)
      @slug = repo.full_name
      @log = log
    end

    def read_guide!
      builder = GuideBuilder.new(@slug)

      read_meta! builder
      read_description! builder
      read_corollary! builder
      read_extra! builder
      read_exercises! builder

      builder.build
    end

    def read_description!(builder)
      description = read_file(File.join(dir, 'description.md'))
      raise 'Missing description file' unless description
      builder.description = description
    end

    def read_corollary!(builder)
      builder.corollary = read_file(File.join(dir, 'corollary.md'))
    end

    def read_extra!(builder)
      builder.extra = read_code_file(dir, 'extra')
    end

    def read_meta!(builder)
      meta = read_yaml_file(File.join(dir, 'meta.yml'))

      builder.language = Bibliotheca::Language.find_by_name meta['language']
      builder.locale = meta['locale']

      read! 'name', builder, meta
      read! 'original_id_format', builder, meta
      read! 'learning', builder, meta
      read! 'beta', builder, meta

      builder.order = Bibliotheca::Ordering.from meta['order']
    end

    def read!(key, builder, meta)
      builder[key] = meta[key]
    end

    def read_exercises!(builder)
      read_exercises do |exercise_builder|
        builder.add_exercise exercise_builder.build
      end
    end

    def read_exercises
      each_exercise_file do |root, position, original_id, name|
        builder = ExerciseBuilder.new
        exercise_reader = ExerciseReader.new(dir)

        builder.meta = exercise_reader.meta(root) || (log.no_meta(name); next)
        builder.original_id = original_id
        builder.name = name
        builder.description = exercise_reader.markdown(root, 'description') || (log.no_description name; next)
        builder.hint = exercise_reader.markdown(root, 'hint')
        builder.corollary = exercise_reader.markdown(root, 'corollary')
        builder.test = exercise_reader.test_code(root)
        builder.extra_code = exercise_reader.extra_code(root)
        builder.expectations = exercise_reader.expectations(root).try { |it| it['expectations'] }
        yield builder
      end
    end

    private

    def each_exercise_file
      Dir.glob("#{@dir}/**").sort.each_with_index do |file, index|
        basename = File.basename(file)
        match = /(\d*)_(.+)/.match basename
        next unless match
        yield file, index + 1, match[1].to_i, match[2]
      end
    end
  end
end