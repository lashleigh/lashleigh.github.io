require 'csv'
require 'json'
require 'yaml'
require 'time'

require 'active_support'
require 'active_support/core_ext'
require 'irb/completion'

def pbcopy(input)
 str = input.to_s
 IO.popen('pbcopy', 'w') { |f| f << str }
 str
end

# Monkey party patch time
module MyExtension
  module Hash 
    def only(*keys)
      ::Hash[[keys, self.values_at(*keys)].transpose]
    end
  end
end
Hash.include MyExtension::Hash

module Enumerable
  def count_by(&block)
    Hash[group_by(&block).map { |key,vals| [key, vals.size] }]
  end
end

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

# Build the jekyll formatted files based on date_read
def post_title(blob)
  begin
    title = blob[:date_read] || blob[:date_added]
    title += '-'
    title += blob[:title].split(' ')[0..8].join('-').downcase.gsub(/[:.',()#?]/,'')
	rescue Exception => e
		puts [blob[:date_read], blob[:title]]
	end
end

def post_yaml(blob)
    {
      date: blob[:date_read] || blob[:date_added],
      title: blob[:title],
      author: blob[:author],
      goodreads_book_id: blob[:book_id].to_s,
    }.stringify_keys.to_yaml(:line_width => -1)
end

def write_post_scaffold_file(book, where = '_books/goodreads')
  f = File.open("./#{where}/#{post_title(book)}.md", "w")
  f.puts(post_yaml(book))
  f.puts("\n---")
  f.puts(book[:my_review].gsub("<br/>", "\n")) if book[:my_review]
  f.close
end

# Instead of modifying the posts over and over again (which would clearly drive me crazy)
# I should just import the goodreads metadata separately. Then the only thing I need to
# put in the front matter of my post is the goodreads book_id.
def write_goodreads_book_data(books, file = "./_data/goodreads/books.yaml")
  ignored_fields = [:my_review, :author_lf, :my_rating, :average_rating, :owned_copies]
  massaged_data = books.map {|r| {r[:book_id] => r.reject {|k, v| v.nil? || ignored_fields.include?(k)}.stringify_keys} }
  f = File.open(file, 'w')
  f.puts(massaged_data.to_yaml(:line_width => -1))
  f.close
end

def read_book_data_and_convert_to_json(file = "./goodreads_library_export.csv")
  res = CSV.read(file, :headers => true, :header_converters => :symbol, :converters => :all);
  res.map {|r| clean(r.to_hash) };
end

# It'll get tedious to re-import things that I've already categorized elsewhere
# and then have to cherry-pick around them. The after param means I only write
# draft posts for dates following a specific one (presumably the one of last import)
def write_draft_posts(books, after = nil)
  books = books.select {|r| r[:date_read] && r[:date_read] > after } unless after.nil?
  books.select {|r| r[:my_review]}.each {|r| write_post_scaffold_file(r)}
end

# This helper reads the locations file and then appends the scaffold for any books
# that are not already present in the yaml. If there is location data already entered
# that is maintained, all other fields are stopmed on.
SHELF_ORDER = %w(currently-reading read skimmed abandoned hold to-read).to_a.map.with_index {|v, i| {v => i}}.reduce(&:merge)

def sort_order(book)
  shelf_order = SHELF_ORDER[book[:exclusive_shelf]] || (puts "No sort order for shelf: #{shelf}"; 999)
  "#{shelf_order}-#{9 - book[:my_rating]}"
end

def update_locations(data, reject_empty = true, location_file = "./_data/locations.json")
  existing_data = JSON.load(File.read(location_file)) || {}

  updates = data.map do |n|
    current = existing_data[n[:book_id].to_s] || {}
    manual = current.fetch("manual", {})
    loc = manual.fetch('location', {})
    loc = {note: nil, name: nil, lat: nil, lng: nil, iso_3166_2: nil} if loc.values.compact.uniq.empty?

    # The location is the most important of the manually attached things, but there is the option to manually
    # add other pieces of metadata here too, tags for example. As I was trying to classify some of the books down
    # to locations it became pretty obvious that their theme was something else entirely.
    manual['location'] = loc

    # What a mess, at some point I'll need to model this properly
    # the v.values.unit blah blah blah is to check if the location hash is empty, the other v.blank? is
    # to make sure I don't stomp on other manual info even if there is no location.
    next if reject_empty && manual.all? {|k, v| v.is_a?(Hash) ? v.values.uniq.compact.empty? : v.blank? }
    
    {n[:book_id] => n.slice(:book_id,:isbn13,:title,:author,:my_rating,:exclusive_shelf).merge(manual: manual) }
  end.compact

  ordered = updates.sort_by {|h| sort_order(h.values.first)}.reduce(&:merge)

  new_json = JSON.pretty_generate(ordered)
  f = File.open(location_file, "w")
  f.write(new_json);
  f.close
end

# Maybe play with the api sometime. Somebody made a ruby client, which was lucky, because from
# reading the goodreads docs I honestly couldn't tell how to get my books.
# https://github.com/sosedoff/goodreads
# https://www.goodreads.com/review/list/47766728.xml?key=REDACTED&v=2&shelf=read