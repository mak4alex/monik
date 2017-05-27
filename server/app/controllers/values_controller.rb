class ValuesController < ApplicationController

  def create
    p params[:a]
    head :ok
  end

end
