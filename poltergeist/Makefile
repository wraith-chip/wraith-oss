# Compiler and flags
CXX      := g++
CXXFLAGS := -Wall -Wextra -O2 -std=c++17

# Project files
SRC  := main.cpp
OBJ  := build/$(SRC:.cpp=.o)
BIN  := poltergeist

# Default target
all: $(BIN)

$(BIN): $(OBJ)
	$(CXX) $(CXXFLAGS) -o $@ $^

# Compilation
build/%.o: %.cpp types.hpp
	mkdir -p build && \
	$(CXX) $(CXXFLAGS) -c $< -o $@

# Clean up build files
clean:
	rm -f $(OBJ) $(BIN)

# Convenience run target
run: $(BIN)
	./$(BIN)

.PHONY: all clean run
