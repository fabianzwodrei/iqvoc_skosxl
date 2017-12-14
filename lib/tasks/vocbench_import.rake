namespace :iqvoc do

  namespace :import do

    desc 'Imports VOCBENCH ntriples data from a given url (URL=...). Use the parameter PREFIX_FOR_ALTLABELS=... for prefLabels that should be importet as altLabels'
    task :vocbench => :environment do
      raise "You have to specify an url for the data file to be imported. Example: rake iqvoc:vocbench_import:url URL=... PREFIX_FOR_ALTLABELS=..." unless ENV['URL']
      raise "You have to specify a PREFIX_FOR_ALTLABELS for the data file to be imported. Example: rake iqvoc:vocbench_import:url URL=... PREFIX_FOR_ALTLABELS=..." unless ENV['PREFIX_FOR_ALTLABELS']

      stdout_logger = Logger.new(STDOUT)
      stdout_logger.level = Logger::INFO

      debug = true
      publish = true

      importer = VocbenchImporter.new(ENV['URL'], URI.parse('http://thesauri.dainst.org/').to_s, MultiLogger.new(stdout_logger, Rails.logger), publish, debug, ENV['PREFIX_FOR_ALTLABELS'])
      importer.run
    end

  end

end
