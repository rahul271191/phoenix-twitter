defmodule App.FavoriteController do
  use App.Web, :controller

  alias App.Favorite
  alias App.Tweet

  plug App.SetUser, [:favorites] when action in [:index]
  plug App.LoginRequired when action in [:create, :delete]

  def index(conn, %{"user_id" => user_id}) do
    query = Favorite
    |> where([f], f.user_id == ^user_id)
    |> join(:left, [f], t in assoc(f, :tweet))
    query = case get_session(conn, :current_user) do
      nil ->
        query
        |> select([f, t], t)
      current_user ->
        query
        |> join(:left, [f, _], f2 in Favorite, f2.tweet_id == f.tweet_id and f2.user_id == ^current_user.id)
        |> select([f, t, f2], %{t | favorite_id: f2.id})
    end
    tweets = Repo.all query
    render conn, "index.html", tweets: tweets
  end

  def create(conn, %{"id" => id}) do
    current_user = conn.assigns[:current_user]
    tweet = Repo.get! Tweet, id
    params = %{user_id: current_user.id, tweet_id: tweet.id}
    case Repo.insert(Favorite.changeset(%Favorite{}, params)) do
      {:ok, _favorite} ->
        redirect conn, to: user_tweet_path(conn, :index, tweet.user_id)
      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Unable to favorite tweet.")
        |> redirect(to: user_tweet_path(conn, :index, tweet.user_id))
        |> halt
    end
  end

  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns[:current_user]
    favorite = Repo.get! Favorite, id
    if current_user.id === favorite.user_id do
      Repo.delete!(favorite)
      redirect conn, to: user_tweet_path(conn, :index, favorite.user_id)
    else
      conn
      |> put_status(:unauthorized)
      |> render(App.ErrorView, "401.html")
    end
  end
end
