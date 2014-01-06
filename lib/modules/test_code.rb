module TestCode
  # This contains test code only meant to be used from the rails console.

  def self.generate_random_body
    example_data = YAML.load_file("#{Rails.root}/config/example_data.yml")
    tags = example_data['tags'].sample(20)
    images = example_data['image_urls'].shuffle
    image_pos = 0
    links = example_data['link_urls'].shuffle
    link_pos = 0

    number_of_paragraphs = rand(1..5)
    summary = Faker::Company.catch_phrase
    body = ""

    (1..number_of_paragraphs).each do |i|
      paragraph = Faker::Lorem.paragraph(1, false, 4)
      words = paragraph.split(/ /)

      stuff_to_add = []
      stuff_to_add += tags.sample(rand(1..3)) if rand(1..3) == 1 # add 1 to 3 tags (1/3 probability)
      stuff_to_add << get_next(links, link_pos) if rand(1..5) == 1 # add 1 link (1/5 probability)
      stuff_to_add.each { |text| words.insert rand(0..words.count), text }
      body += words.join(' ')

      # now add the dividers if needed
      if i < number_of_paragraphs
	    body += "<br><br>" # always add a paragraph separator
        body += "#{get_next(images, image_pos)}<br><br>" if rand(1..4) == 1 # add image (1/4 probability)
        body += '-----<br><br>' if rand(1..3) == 1 # add section break (1/3 probability)
      end
    end

    {:summary => summary, :body => body}
  end

  # returns list[position] and increments position or sets it to zero
  def self.get_next(list, position)
  	return_value = list[position]
  	position = ((position + 1) < list.count) ? (position + 1) : 0
  	return_value
  end
end