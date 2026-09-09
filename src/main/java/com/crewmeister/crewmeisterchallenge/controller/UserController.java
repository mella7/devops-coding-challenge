package com.crewmeister.crewmeisterchallenge.controller;

import com.crewmeister.crewmeisterchallenge.model.User;
import com.crewmeister.crewmeisterchallenge.repository.UserRepository;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class UserController {

  private final UserRepository userRepository;

  public UserController(UserRepository userRepository) {
    this.userRepository = userRepository;
  }

  @GetMapping("/user")
  public ResponseEntity<String> getUser(@RequestParam Long id) {
    return userRepository.findById(id)
        .map(user -> ResponseEntity.ok("Greetings from Crewmeister, " + user.getName() + "!"))
        .orElseGet(() -> ResponseEntity.status(HttpStatus.NOT_FOUND)
            .body("User with id " + id + " not found"));
  }

  @PostMapping("/user")
  public ResponseEntity<String> createUser(@RequestBody UserRequest request) {
    if (request == null || request.name() == null || request.name().isBlank()) {
      return ResponseEntity.badRequest().body("Field 'name' is required");
    }
    User user = new User();
    user.setName(request.name());
    User saved = userRepository.save(user);
    return ResponseEntity.status(HttpStatus.CREATED)
        .body("Greetings from Crewmeister, " + saved.getName() + "!");
  }

  public record UserRequest(String name) {}
}
