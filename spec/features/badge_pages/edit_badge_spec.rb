require 'spec_helper'

feature "Edit Badge" do
  
  given(:badge) { FactoryGirl.create(:badge) }

  background(:each) { visit edit_badge_path(badge) }

  scenario "User updates fields and clicks save" do
    page.fill_in "badge_name", with: "Updated Badge Name"
    page.fill_in "badge_image_url", with: "http://example.com/updated.png"
    page.fill_in "badge_summary", with: "Updated Badge Summary"
    page.fill_in "badge_description", with: "Updated Badge Description"
    click_button "Update Badge"

    # This should take us back to the badge detail with the new values.
    page.should have_selector('h1', text: "Updated Badge Name")
    page.should have_text("Updated Badge Name")
    page.should have_selector("img[src='http://example.com/updated.png']")
    page.should have_text("Updated Badge Summary")
    page.should have_text("Updated Badge Description")
  end

  scenario "User updates fields and clicks cancel" do
    page.fill_in "badge_name", with: "Updated Badge Name"
    page.fill_in "badge_image_url", with: "http://example.com/updated.png"
    page.fill_in "badge_summary", with: "Updated Badge Summary"
    page.fill_in "badge_description", with: "Updated Badge Description"
    click_link "Cancel"

    # This should take us back to the badge detail with unchanged values.
    page.should have_selector('h1', text: badge.name)
    page.should_not have_text("Updated Badge Name")
    page.should_not have_selector("img[src='http://example.com/updated.png']")
    page.should_not have_text("Updated Badge Summary")
    page.should_not have_text("Updated Badge Description")
  end

end
