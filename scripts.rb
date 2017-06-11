require 'csv'
require 'json'
require 'yaml'
require 'time'

require 'active_support'
require 'active_support/core_ext'

# Markey party patch time
module MyExtension
  module Hash 
    def only(*keys)
      ::Hash[[keys, self.values_at(*keys)].transpose]
    end
  end
end
Hash.include MyExtension::Hash

# Correct awkward formatting
# * isbn fields have =ID and get escaped awkwardly
# * time fields aren't iso8061
def clean(blob)
  blob[:isbn].gsub!(/[="]/,'')
  blob[:isbn13].gsub!(/[="]/,'')
  blob[:date_read] = Time.parse(blob[:date_read]).strftime("%F") if blob[:date_read]
  blob[:date_added] = Time.parse(blob[:date_added]).strftime("%F") if blob[:date_added]
  return blob
end

res = CSV.read("./goodreads_export.csv", :headers => true, :header_converters => :symbol, :converters => :all)
res = res.map {|r| clean(r.to_hash) }

shelves = ["currently-reading", "read", "skimmed"]
res.select! {|r| shelves.include?(r[:exclusive_shelf]) }

# Build the jekyll formatted files based on date_read
def post_title(blob)
  begin
    title = blob[:date_read] || blob[:date_added]
    title += '-'
    title += blob[:title].split(' ')[0..4].join('-').downcase.gsub(/[:.',()#?]/,'')
	rescue => e
		puts [blob[:date_read], blob[:title]]
	end
end

def post_yaml(blob)
    subset = {
      date: blob[:date_read] || blob[:date_added],
      goodreads_id: blob[:book_id]
    }

    subset.merge!(
      blob.only(
    	   :title,
    	   :author,
         :date_read,
    	   :isbn13,
    	   :year_published,
    	   :original_publication_year,
    	   :date_added,
         :additional_authors,
         :publisher,
         :binding,
         :number_of_pages,
      ).reject {|k, v| v.nil?}
    )

    subset.stringify_keys.to_yaml
end

res.map do |r|
	f = File.open("./_posts/#{post_title(r)}.md", "w")
	f.puts(post_yaml(r))
	f.puts("\n---")
	f.puts(r[:my_review]) if r[:my_review]
	f.close
end