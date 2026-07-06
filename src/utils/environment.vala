public enum EVar {
  CACHE_FOLDER,
}

public class Env {
  private bool has_folder { get; set; }

  public void set (EVar evar, bool state) {
    switch (evar) {
    case CACHE_FOLDER:
      has_folder = state;
      break;
    }
  }

  public bool get (EVar evar) {
    switch (evar) {
    case CACHE_FOLDER:
      return has_folder;
    }
    return false;
  }
}
