require 'spec_helper'

feature "Site Navigation" do
  
  scenario "User goes to root url" do
    visit "/"
    page.should have_selector('h1', text: "All Badges")
  end

end
