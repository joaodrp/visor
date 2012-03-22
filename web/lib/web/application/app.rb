require 'sinatra/base'
require "google_visualr"

module Visor
  module Web
    class App < Sinatra::Base

      set :static, true
      set :public_folder, File.expand_path('..', __FILE__)
      set :views, File.expand_path('../views', __FILE__)

      configure :development do
        require 'sinatra/reloader'
        register Sinatra::Reloader
      end

      helpers do
        WIDTH  = 450
        HEIGHT = 350

        def stores_pie
          client = Visor::Web::Meta.new
          images = client.get_images

          s3 = cumulus = walrus = hdfs = http = fs = 0
          images.each do |img|
            s3      += img[:store] == 's3' ? 1 : 0
            cumulus += img[:store] == 'cumulus' ? 1 : 0
            walrus  += img[:store] == 'walrus' ? 1 : 0
            hdfs    += img[:store] == 'hdfs' ? 1 : 0
            http    += img[:store] == 'http' ? 1 : 0
            fs      += img[:store] == 'fs' ? 1 : 0
          end

          data_table = GoogleVisualr::DataTable.new
          data_table.new_column('string', 'OS')
          data_table.new_column('number', 'Number of Images')
          data_table.add_rows(6)
          data_table.set_cell(0, 0, 'S3')
          data_table.set_cell(0, 1, s3)
          data_table.set_cell(1, 0, 'Cumulus')
          data_table.set_cell(1, 1, cumulus)
          data_table.set_cell(2, 0, 'Walrus')
          data_table.set_cell(2, 1, walrus)
          data_table.set_cell(3, 0, 'HDFS')
          data_table.set_cell(3, 1, hdfs)
          data_table.set_cell(4, 0, 'HTTP')
          data_table.set_cell(4, 1, http)
          data_table.set_cell(5, 0, 'FS')
          data_table.set_cell(5, 1, fs)

          opts = {:width => WIDTH, :height => HEIGHT}
          GoogleVisualr::Interactive::PieChart.new(data_table, opts)
        end


        def top_distros
          client = Visor::Web::Meta.new
          images = client.get_images

          ubuntu = rhel = fedora = centos = suse = others = 0
          images.each do |img|
            case img[:name]
              when /ubuntu/i
                ubuntu += 1
              when /redhat/i || /rhel/i
                rhel += 1
              when /fedora/i
                fedora += 1
              when /centos/i
                centos += 1
              when /suse/i
                suse += 1
              else
                others += 1
            end
          end

          data_table = GoogleVisualr::DataTable.new
          #data_table.new_column('number', 'Ubuntu')
          #data_table.new_column('number', 'RHEL')
          #data_table.new_column('number', 'Fedora')
          #data_table.new_column('number', 'CentOS')
          data_table.new_column('string', 'Distro')
          data_table.new_column('number', 'Quantity')
          data_table.add_rows(6)
          data_table.set_cell(0, 0, 'Ubuntu')
          data_table.set_cell(0, 1, ubuntu)
          data_table.set_cell(1, 0, 'RHEL')
          data_table.set_cell(1, 1, rhel)
          data_table.set_cell(2, 0, 'Fedora')
          data_table.set_cell(2, 1, fedora)
          data_table.set_cell(3, 0, 'CentOS')
          data_table.set_cell(3, 1, centos)
          data_table.set_cell(4, 0, 'SUSE')
          data_table.set_cell(4, 1, suse)
          data_table.set_cell(5, 0, 'Others')
          data_table.set_cell(5, 1, others)

          opts = {:width => WIDTH, :height => HEIGHT}
          GoogleVisualr::Interactive::ColumnChart.new(data_table, opts)
        end


      end

      get '/' do
        @title = 'Home'
        @pie   = stores_pie
        @bars = top_distros
        erb :index
      end
    end
  end
end

