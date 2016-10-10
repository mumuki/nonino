module Bibliotheca::Collection
  module Guides
    extend Mumukit::Service::Collection
    extend Bibliotheca::Collection::WithSlug

    def self.migrate_exercises!(query={})
      migrate! query do |guide|
        guide.exercises.each { |exercise| yield exercise }
      end
    end

    private

    def self.mongo_collection_name
      :guides
    end

    def self.mongo_database
      Bibliotheca::Database
    end

    def self.wrap(it)
      Bibliotheca::Guide.new(it)
    end

    def self.wrap_array(it)
      Bibliotheca::Collection::GuideArray.new(it)
    end
  end

  class GuideArray < Mumukit::Service::DocumentArray

    def options
      {only: [:id, :name, :slug, :language, :type]}
    end

    def key
      :guides
    end
  end
end

