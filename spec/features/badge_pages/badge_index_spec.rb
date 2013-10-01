require 'spec_helper'

feature "Badge Index" do
  
  background(:each) { visit "/badges" }

  scenario "User sees correct titles" do
    page.should have_title("All Badges")
    page.should have_selector('h1', "All Badges")
  end

  scenario "User sees pagination" do
    #page.should have_selector('paginate')
    Badge.asc(:name).page(1).per(APP_CONFIG['page_size']).each do |badge|
      page.should have_selector('li', text: badge.name)
    end
  end

  scenario "User clicks New Badge button" do
    page.should have_link("New Badge")
    click_link "New Badge" 
    page.should have_selector('h1', text: "Create New Badge")
  end

  given(:first_badge_link) { first("a.badge-detail-text-link") }

  scenario "User clicks Badge detail link" do
    first_badge_link.click
    page.should have_selector('h1', text: first_badge_link.text )
  end

end
