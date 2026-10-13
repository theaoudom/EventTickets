package com.kosign.eventtickets.domain.entity;

import com.kosign.eventtickets.util.DateTimes;
import jakarta.persistence.Column;
import jakarta.persistence.MappedSuperclass;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import lombok.Getter;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;

/** Fills the REG_DTM / MOD_DTM / REG_ID / MOD_ID audit columns. */
@Getter
@MappedSuperclass
public abstract class BaseEntity {

    @Column(name = "REG_DTM", length = 14, nullable = false, updatable = false)
    private String regDtm;

    @Column(name = "MOD_DTM", length = 14, nullable = false)
    private String modDtm;

    @Column(name = "REG_ID", length = 50, nullable = false, updatable = false)
    private String regId;

    @Column(name = "MOD_ID", length = 50, nullable = false)
    private String modId;

    @PrePersist
    void onCreate() {
        regDtm = modDtm = DateTimes.now();
        regId = modId = currentUsername();
    }

    @PreUpdate
    void onUpdate() {
        modDtm = DateTimes.now();
        modId = currentUsername();
    }

    private static String currentUsername() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        return auth == null || !auth.isAuthenticated() ? "system" : auth.getName();
    }
}
