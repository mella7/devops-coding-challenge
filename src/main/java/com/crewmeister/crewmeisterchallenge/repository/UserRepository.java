package com.crewmeister.crewmeisterchallenge.repository;

import com.crewmeister.crewmeisterchallenge.model.User;
import java.util.Optional;
import org.springframework.data.repository.CrudRepository;

public interface UserRepository extends CrudRepository<User, Long> {

  @Override
  Optional<User> findById(Long id);
}
