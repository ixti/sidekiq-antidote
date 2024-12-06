# frozen_string_literal: true

require "sidekiq"
require "sidekiq/web"

module Sidekiq
  module Antidote
    module Web
      VIEWS = Pathname.new(__dir__).join("../../../web/views").expand_path

      def self.registered(app) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        app.get("/antidote") do
          @inhibitors = Antidote.inhibitors

          erb(VIEWS.join("index.html.erb").read)
        end

        app.get("/antidote/add") do
          @treatment       = Sidekiq::Antidote::Inhibitor::TREATMENTS.first
          @class_qualifier = ""

          erb(VIEWS.join("add.html.erb").read)
        end

        app.post("/antidote/add") do
          @treatment             = params[:treatment]
          @treatment             = "skip" unless Sidekiq::Antidote::Inhibitor::TREATMENTS.include?(@treatment)
          @class_qualifier       = params[:class_qualifier]
          @class_qualifier_error = nil

          begin
            Sidekiq::Antidote::ClassQualifier.new(@class_qualifier)
          rescue StandardError => e
            @class_qualifier_error = e.message
          end

          if @class_qualifier_error
            erb(VIEWS.join("add.html.erb").read)
          else
            Antidote.add(treatment: @treatment, class_qualifier: @class_qualifier)
            redirect "#{root_path}antidote"
          end
        end

        app.post("/antidote/:id/delete") do
          Antidote.delete(route_params[:id])

          Sidekiq::Antidote::SuspensionGroup.new(name: route_params[:id]).release!

          redirect "#{root_path}antidote"
        end
      end
    end
  end
end

Sidekiq::Web.register(Sidekiq::Antidote::Web)
Sidekiq::Web.tabs["Antidote"] = "antidote"
Sidekiq::Web.locales << Pathname.new(__dir__).join("../../../web/locales").expand_path.to_s
