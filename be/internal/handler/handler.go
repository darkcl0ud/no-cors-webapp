package handler

import (
	"net/http"

	"github.com/darkcl0ud/no-cors-webapp/be/internal/api"
	"github.com/gin-gonic/gin"
)

type Server struct{}

var _ api.ServerInterface = (*Server)(nil)

func (s Server) GetMovies(c *gin.Context) {
	movies := []api.Movie{
		{Id: "1", Name: "Movie 1", Description: "Movie 1 description"},
		{Id: "2", Name: "Movie 2", Description: "Movie 2 description"},
	}
	c.JSON(http.StatusOK, movies)
}

func (s Server) GetMoviesMovieId(c *gin.Context, movieId string) {
	movie := api.Movie{
		Id: movieId, Name: "Movie 1", Description: "Movie 1 description",
	}
	c.JSON(http.StatusOK, movie)
}

func (s Server) GetHealth(c *gin.Context) {
	c.JSON(http.StatusNoContent, map[string]string{})
}
