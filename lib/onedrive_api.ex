defmodule OneDriveApi do
  @item_by_id_url "https://api.onedrive.com/v1.0/drive/items/"
  @item_by_path_url "https://api.onedrive.com/v1.0/drive/root:/"

  def view_changes_by_path(pid, path, status_token) do
    Tokens.check_token(pid)
    url =
      @item_by_path_url <> path
    <> ":/view.delta"
    <> "?select=id,name,eTag,cTag,deleted,file,folder,fileSystemInfo,remoteItem,parentReference"

    url = url <>
      case String.valid?(status_token) do
        :true -> "?token=" <> status_token
      end

    get(url)
  end

  def get(url) do

  end

  defmodule OneDriveSync do

  end
end
