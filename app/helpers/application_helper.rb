module ApplicationHelper

# This methode allow me to sort my list when i will click on it
  def sortable (column, title = nil)
    title ||= column.titleize
    # we check if the column match the sort column and if the direction is asc then we do desc if not we do asc
    direction = column == params[:sort] && params[:direction] == "asc" ? "desc" : "asc"
    link_to title, :sort => column , :direction => direction

end
end
