require 'spec_helper'

feature "Create New Badge" do
  
  background(:each) { visit "/badges/new" }

  scenario "User fills in all fields correctly" do
    page.fill_in "badge_name", with: "New Badge Name"
    page.fill_in "badge_image_url", with: "http://example.com/image.png"
    page.fill_in "badge_summary", with: "New Badge Summary"
    page.fill_in "badge_description", with: "New Badge Description"
    expect { click_button "Create Badge" }.to change(Badge, :count)
  end

  scenario "User leaves all fields blank" do
    expect { click_button "Create Badge" }.not_to change(Badge, :count)
  end

  scenario "User clicks the cancel button" do
    page.should have_link("Cancel")
    click_link "Cancel" 
    page.should have_selector('h1', text: "All Badges")
  end

end
