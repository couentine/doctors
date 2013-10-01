require 'spec_helper'

feature "View Badge Detail" do
  
  given(:badge) { FactoryGirl.create(:badge) }

  background(:each) { visit badge_path(badge) }

  scenario "User sees all fields correctly" do
    page.should have_text(badge.name)
    page.should have_selector("img[src='#{badge.image_url}']")
    page.should have_text(badge.summary)
    page.should have_text(badge.description)
    
    page.should have_link("Delete Badge")
  end

  scenario "User clicks the edit button" do
    page.should have_link("Edit Badge")
    click_link "Edit Badge" 
    page.should have_selector('h1', text: "Edit Badge")
  end

  scenario "User clicks the delete button" do
    page.should have_link("Delete Badge")
    expect { click_link "Delete Badge" }.to change(Badge, :count).by(-1)
    page.should have_selector('h1', text: "All Badges")
  end

end
